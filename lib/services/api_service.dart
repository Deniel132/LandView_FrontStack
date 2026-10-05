import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/calcado.dart';
import '../models/recomendacao.dart';

/// Erro já traduzido para uma mensagem que pode ir direto para a tela.
class ApiException implements Exception {
  final String mensagem;
  final int? status;

  ApiException(this.mensagem, {this.status});

  @override
  String toString() => mensagem;
}

/// Única porta de comunicação entre a interface Flutter e a API Python.
///
/// Centraliza URLs, requisições HTTP, conversão de respostas JSON e mensagens
/// de erro. Assim, as telas não precisam conhecer detalhes da rede.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const _timeout = Duration(seconds: 10);

  /// Endereço da API. Para trocar sem mexer no código:
  ///   flutter run --dart-define=API_URL=http://192.168.0.10:8000
  /// No emulador Android, "localhost" é o próprio emulador; o computador
  /// é visto como 10.0.2.2.
  static String get baseUrl {
    const doAmbiente = String.fromEnvironment('API_URL');
    if (doAmbiente.isNotEmpty) return doAmbiente;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  // Se a API passar a exigir JWT, é aqui que entra:
  //   'Authorization': 'Bearer $token'
  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      };

  Uri _uri(String caminho) => Uri.parse('$baseUrl$caminho');

  // Operações do catálogo de calçados (criar, consultar, atualizar e excluir).

  Future<List<Calcado>> listar() async {
    final json = await _enviar(() => http.get(_uri('/calcados'), headers: _headers));
    return _ler(() => (json as List)
        .map((e) => Calcado.fromJson(e as Map<String, dynamic>))
        .toList());
  }

  Future<Calcado> buscar(int id) async {
    final json = await _enviar(() => http.get(_uri('/calcados/$id'), headers: _headers));
    return _ler(() => Calcado.fromJson(json as Map<String, dynamic>));
  }

  /// Envia uma foto do dispositivo e devolve o endereço persistente da API.
  ///
  /// O endpoint `/imagens` recebe multipart/form-data no campo `arquivo` e
  /// responde com `{ "imagem_url": "..." }`.
  Future<String> enviarImagem(Uint8List bytes, String nomeArquivo) async {
    try {
      final pedido = http.MultipartRequest('POST', _uri('/imagens'))
        ..headers['Accept'] = 'application/json'
        ..files.add(http.MultipartFile.fromBytes(
          'arquivo',
          bytes,
          filename: nomeArquivo,
        ));

      final enviada = await pedido.send().timeout(_timeout);
      final resposta = await http.Response.fromStream(enviada).timeout(_timeout);
      final json = _tratar(resposta);
      final endereco = _ler(() {
        final valor = (json as Map<String, dynamic>)['imagem_url'] as String;
        if (valor.trim().isEmpty) {
          throw const FormatException('A API devolveu uma URL vazia.');
        }
        return valor;
      });

      final uri = Uri.parse(endereco);
      return uri.hasScheme ? uri.toString() : Uri.parse(baseUrl).resolveUri(uri).toString();
    } on ApiException catch (e) {
      if (e.status == 404 || e.status == 405) {
        throw ApiException(
          'A API ainda não oferece envio de fotos. Configure o endpoint POST /imagens conforme API_CONTRATO.md.',
          status: e.status,
        );
      }
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'A API demorou demais para receber a foto. Confira se o servidor está ligado em $baseUrl.',
      );
    } catch (_) {
      throw ApiException(
        'Não foi possível enviar a foto para a API em $baseUrl. Confira se o endpoint /imagens está configurado.',
      );
    }
  }

  Future<Calcado> criar(Calcado calcado) async {
    final json = await _enviar(() => http.post(
          _uri('/calcados'),
          headers: _headers,
          body: jsonEncode(calcado.toJson()),
        ));
    return _ler(() => Calcado.fromJson(json as Map<String, dynamic>));
  }

  Future<Calcado> atualizar(Calcado calcado) async {
    final json = await _enviar(() => http.put(
          _uri('/calcados/${calcado.id}'),
          headers: _headers,
          body: jsonEncode(calcado.toJson()),
        ));
    return _ler(() => Calcado.fromJson(json as Map<String, dynamic>));
  }

  Future<void> excluir(int id) async {
    await _enviar(() => http.delete(_uri('/calcados/$id'), headers: _headers));
  }

  // Envia as medidas para a API; o cálculo pertence ao backend Python.

  Future<Recomendacao> recomendar({
    required int calcadoId,
    required double medidaPeCm,
    double? numeracaoHabitual,
    String? marcaHabitual,
  }) async {
    final corpo = <String, dynamic>{
      'calcado_id': calcadoId,
      'medida_pe_cm': medidaPeCm,
      if (numeracaoHabitual != null) 'numeracao_habitual': numeracaoHabitual,
      if (marcaHabitual != null) 'marca_habitual': marcaHabitual,
    };
    final json = await _enviar(() => http.post(
          _uri('/recomendacoes'),
          headers: _headers,
          body: jsonEncode(corpo),
        ));
    return _ler(() => Recomendacao.fromJson(json as Map<String, dynamic>));
  }

  // Tratamento compartilhado de requisições, respostas e erros.

  /// Executa a chamada e converte qualquer falha em [ApiException].
  Future<dynamic> _enviar(Future<http.Response> Function() chamada) async {
    try {
      final resposta = await chamada().timeout(_timeout);
      return _tratar(resposta);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'A API demorou demais para responder. Confira se o servidor está ligado em $baseUrl.',
      );
    } catch (_) {
      throw ApiException(
        'Não foi possível conectar à API em $baseUrl. Confira o servidor e a rede.',
      );
    }
  }

  dynamic _tratar(http.Response resposta) {
    final texto = utf8.decode(resposta.bodyBytes);
    dynamic json;
    if (texto.isNotEmpty) {
      try {
        json = jsonDecode(texto);
      } catch (_) {
        json = null;
      }
    }

    if (resposta.statusCode >= 200 && resposta.statusCode < 300) return json;
    throw ApiException(
      _mensagemDeErro(resposta.statusCode, json),
      status: resposta.statusCode,
    );
  }

  /// Lê o campo `detail` do FastAPI (texto simples ou lista do Pydantic).
  String _mensagemDeErro(int status, dynamic json) {
    if (json is Map && json['detail'] != null) {
      final detalhe = json['detail'];
      if (detalhe is String) return detalhe;
      if (detalhe is List && detalhe.isNotEmpty) {
        return detalhe.map((e) {
          if (e is Map) {
            final campo = (e['loc'] as List?)?.where((p) => p != 'body').join('.');
            final msg = e['msg'];
            return (campo == null || campo.isEmpty) ? '$msg' : '$campo: $msg';
          }
          return '$e';
        }).join('\n');
      }
    }
    switch (status) {
      case 401:
        return 'Acesso não autorizado.';
      case 404:
        return 'Registro não encontrado.';
      case 422:
        return 'Os dados enviados são inválidos.';
      default:
        return status >= 500
            ? 'Erro interno no servidor (código $status).'
            : 'A API recusou a requisição (código $status).';
    }
  }

  /// Protege contra resposta fora do contrato (campo faltando, tipo errado).
  T _ler<T>(T Function() converter) {
    try {
      return converter();
    } catch (_) {
      throw ApiException(
        'A API respondeu em um formato inesperado. Confira o contrato dos endpoints.',
      );
    }
  }
}
