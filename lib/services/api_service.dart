import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/calcado.dart';
import '../models/dashboard.dart';
import '../models/recomendacao.dart';
import '../models/usuario.dart';
import '../models/venda.dart';
import 'api_exception.dart';
import 'dados_demo.dart';
import 'sessao.dart';

// Quem importa o ApiService também enxerga o ApiException.
export 'api_exception.dart';

/// Única porta de saída do app para a rede. Nenhuma tela monta URL
/// ou lê JSON por conta própria: tudo passa por aqui.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const _timeout = Duration(seconds: 10);

  /// A interface roda com dados locais por padrão enquanto o backend não está
  /// pronto. Assim, as telas e os botões podem ser demonstrados sem a API.
  /// Quando o backend estiver disponível, use `--dart-define=DEMO=false`.
  static const bool modoDemo = bool.fromEnvironment('DEMO', defaultValue: true);

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

  /// Depois do login, toda requisição leva o token no cabeçalho
  /// `Authorization: Bearer <token>`.
  Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
    if (Sessao.instance.token != null)
      'Authorization': 'Bearer ${Sessao.instance.token}',
  };

  Uri _uri(String caminho) => Uri.parse('$baseUrl$caminho');

  // --------------------------------------------------------------- Login

  /// Faz login na API e guarda o token na [Sessao].
  Future<Usuario> login(String email, String senha) async {
    if (modoDemo) {
      final usuario = await DadosDemo.instance.login(email);
      Sessao.instance.iniciar('token-demo', usuario);
      return usuario;
    }

    final json = await _enviar(
      () => http.post(
        _uri('/api/user/login'),
        headers: _headers,
        body: jsonEncode({'email': email, 'password': senha}),
      ),
      autenticado: false, // 401 aqui é "senha errada", não "sessão expirada"
    );
    return _ler(() {
      final token = json is String
          ? json
          : (json as Map<String, dynamic>)['access_token'] as String;
      if (token.trim().isEmpty) {
        throw const FormatException('A API devolveu um token vazio.');
      }
      final usuario = Usuario(
        nome: email.trim().split('@').first,
        email: email.trim(),
      );
      Sessao.instance.iniciar(token, usuario);
      return usuario;
    });
  }

  /// Cria uma conta na rota pública da API.
  Future<void> criarConta(String email, String senha) async {
    if (modoDemo) {
      throw ApiException(
        'O cadastro de contas só funciona quando o app está conectado à API.',
      );
    }

    await _enviar(
      () => http.post(
        _uri('/api/user/'),
        headers: _headers,
        body: jsonEncode({
          'email': email.trim(),
          'password': senha,
          'role': 'USER',
        }),
      ),
      autenticado: false,
    );
  }

  // ---------------------------------------------------------- Dashboard

  Future<Dashboard> dashboard() async {
    if (modoDemo) return DadosDemo.instance.dashboard();
    dynamic json;
    try {
      json = await _enviar(
        () => http.get(_uri('/dashboard'), headers: _headers),
      );
    } on ApiException catch (e) {
      if (e.status == 404) {
        throw ApiException(
          'O login funcionou, mas esta API ainda não implementa GET /dashboard. '
          'A equipe do backend precisa criar esse endpoint para carregar o painel.',
          status: 404,
        );
      }
      rethrow;
    }
    return _ler(() => Dashboard.fromJson(json as Map<String, dynamic>));
  }

  // ---------------------------------------------------------------- CRUD

  Future<List<Calcado>> listar() async {
    if (modoDemo) return DadosDemo.instance.listar();
    final json = await _enviar(
      () => http.get(_uri('/calcados'), headers: _headers),
    );
    return _ler(
      () => (json as List)
          .map((e) => Calcado.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<Calcado> buscar(int id) async {
    if (modoDemo) return DadosDemo.instance.buscar(id);
    final json = await _enviar(
      () => http.get(_uri('/calcados/$id'), headers: _headers),
    );
    return _ler(() => Calcado.fromJson(json as Map<String, dynamic>));
  }

  /// Envia uma foto para a API e devolve a URL persistente retornada por ela.
  Future<String> enviarImagem(Uint8List bytes, String nomeArquivo) async {
    if (modoDemo) {
      throw ApiException(
        'O envio de fotos não está disponível no modo demonstração.',
      );
    }

    try {
      final pedido = http.MultipartRequest('POST', _uri('/imagens'))
        ..headers['Accept'] = 'application/json'
        ..headers.addAll({
          if (Sessao.instance.token != null)
            'Authorization': 'Bearer ${Sessao.instance.token}',
        })
        ..files.add(
          http.MultipartFile.fromBytes('arquivo', bytes, filename: nomeArquivo),
        );

      final enviada = await pedido.send().timeout(_timeout);
      final resposta = await http.Response.fromStream(
        enviada,
      ).timeout(_timeout);
      final json = _tratar(resposta, true);
      final endereco = _ler(() {
        final valor = (json as Map<String, dynamic>)['imagem_url'] as String;
        if (valor.trim().isEmpty) {
          throw const FormatException('A API devolveu uma URL vazia.');
        }
        return valor;
      });

      final uri = Uri.parse(endereco);
      return uri.hasScheme
          ? uri.toString()
          : Uri.parse(baseUrl).resolveUri(uri).toString();
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
        'Não foi possível enviar a foto para a API em $baseUrl. Confira o endpoint /imagens.',
      );
    }
  }

  Future<Calcado> criar(Calcado calcado) async {
    if (modoDemo) return DadosDemo.instance.criar(calcado);
    final json = await _enviar(
      () => http.post(
        _uri('/calcados'),
        headers: _headers,
        body: jsonEncode(calcado.toJson()),
      ),
    );
    return _ler(() => Calcado.fromJson(json as Map<String, dynamic>));
  }

  Future<Calcado> atualizar(Calcado calcado) async {
    if (modoDemo) return DadosDemo.instance.atualizar(calcado);
    final json = await _enviar(
      () => http.put(
        _uri('/calcados/${calcado.id}'),
        headers: _headers,
        body: jsonEncode(calcado.toJson()),
      ),
    );
    return _ler(() => Calcado.fromJson(json as Map<String, dynamic>));
  }

  Future<void> excluir(int id) async {
    if (modoDemo) return DadosDemo.instance.excluir(id);
    await _enviar(() => http.delete(_uri('/calcados/$id'), headers: _headers));
  }

  Future<VendaRegistrada> registrarVenda({
    required int calcadoId,
    required int quantidade,
  }) async {
    if (modoDemo) {
      return DadosDemo.instance.registrarVenda(
        calcadoId: calcadoId,
        quantidade: quantidade,
      );
    }
    final json = await _enviar(
      () => http.post(
        _uri('/vendas'),
        headers: _headers,
        body: jsonEncode({'calcado_id': calcadoId, 'quantidade': quantidade}),
      ),
    );
    return _ler(() => VendaRegistrada.fromJson(json as Map<String, dynamic>));
  }

  // -------------------------------------------------------- Recomendação

  Future<Recomendacao> recomendar({
    required int calcadoId,
    required double medidaPeCm,
    double? numeracaoHabitual,
    String? marcaHabitual,
  }) async {
    if (modoDemo) {
      return DadosDemo.instance.recomendar(
        calcadoId: calcadoId,
        medidaPeCm: medidaPeCm,
      );
    }
    final corpo = <String, dynamic>{
      'calcado_id': calcadoId,
      'medida_pe_cm': medidaPeCm,
      if (numeracaoHabitual != null) 'numeracao_habitual': numeracaoHabitual,
      if (marcaHabitual != null) 'marca_habitual': marcaHabitual,
    };
    final json = await _enviar(
      () => http.post(
        _uri('/recomendacoes'),
        headers: _headers,
        body: jsonEncode(corpo),
      ),
    );
    return _ler(() => Recomendacao.fromJson(json as Map<String, dynamic>));
  }

  // ------------------------------------------------------------ Internos

  /// Executa a chamada e converte qualquer falha em [ApiException].
  Future<dynamic> _enviar(
    Future<http.Response> Function() chamada, {
    bool autenticado = true,
  }) async {
    try {
      final resposta = await chamada().timeout(_timeout);
      return _tratar(resposta, autenticado);
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

  dynamic _tratar(http.Response resposta, bool autenticado) {
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

    // Token recusado em uma rota protegida: encerra a sessão e o app
    // volta sozinho para a tela de login.
    if (resposta.statusCode == 401 && autenticado) {
      Sessao.instance.expirar();
      throw ApiException('Sua sessão expirou. Entre novamente.', status: 401);
    }

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
        return detalhe
            .map((e) {
              if (e is Map) {
                final campo = (e['loc'] as List?)
                    ?.where((p) => p != 'body')
                    .join('.');
                final msg = e['msg'];
                return (campo == null || campo.isEmpty)
                    ? '$msg'
                    : '$campo: $msg';
              }
              return '$e';
            })
            .join('\n');
      }
    }
    switch (status) {
      case 401:
        return 'E-mail ou senha incorretos.';
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
