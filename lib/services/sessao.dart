// Importa suporte a codificação e decodificação JSON
import 'dart:convert';
// Importa suporte a ValueNotifier e callbacks reativos do Flutter
import 'package:flutter/foundation.dart';
// Pacote oficial para persistência de dados em chave-valor (localStorage no Web, SharedPreferences no Android/iOS)
import 'package:shared_preferences/shared_preferences.dart';
// Importa o modelo de usuário autenticado
import '../models/usuario.dart';
// Importa o modelo de calçado e medidas de numeração
import '../models/calcado.dart';

/// Gerenciador de estado e persistência local da sessão do usuário e do token Bearer.
///
/// Salva as credenciais no armazenamento local do navegador ou dispositivo (`SharedPreferences`),
/// garantindo que o usuário permaneça autenticado mesmo ao pressionar F5 ou reabrir o site.
class Sessao {
  // Construtor privado para garantir o padrão de projeto Singleton
  Sessao._();

  // Instância única global acessível através de Sessao.instance
  static final Sessao instance = Sessao._();

  // Chaves de armazenamento persistente
  static const String _chaveToken = 'landview_token';
  static const String _chaveUsuario = 'landview_usuario';

  // Armazena a string do token de autenticação emitido pelo backend
  String? _token;

  // Armazena os dados do usuário autenticado atualmente
  Usuario? _usuario;

  /// Notificador reativo (ValueNotifier) que dispara atualizações nas AppBars e cabeçalhos
  /// quando o usuário realiza login, altera dados de perfil ou faz logout.
  final ValueNotifier<Usuario?> usuarioNotifier = ValueNotifier<Usuario?>(null);

  /// Callback registrado pelo `main.dart` para redirecionar o usuário à tela de login
  /// caso o backend rejeite a requisição com código 401 (token expirado ou inválido).
  VoidCallback? aoExpirar;

  /// Retorna verdadeiro se existir um token armazenado na sessão
  bool get logado => _token != null;

  /// Retorna o token atual ou nulo se deslogado
  String? get token => _token;

  /// Retorna o usuário logado atualmente ou nulo
  Usuario? get usuario => _usuario;

  /// Inicializa a sessão ativa gravando o token, o usuário e persistindo no armazenamento local (localStorage)
  void iniciar(String token, Usuario usuario) {
    // Guarda o token de acesso na memória
    _token = token;
    // Guarda a entidade de usuário na memória
    _usuario = usuario;
    // Emite atualização reativa para os widgets ouvintes
    usuarioNotifier.value = usuario;

    // Salva de forma assíncrona no SharedPreferences para resistir a F5 / recarregamento de página
    _salvarNoDisco(token, usuario);
  }

  /// Restaura a sessão previamente salva ao abrir ou recarregar a página (F5)
  Future<bool> restaurar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenSalvo = prefs.getString(_chaveToken);
      final usuarioStr = prefs.getString(_chaveUsuario);

      if (tokenSalvo != null && usuarioStr != null) {
        final usuarioMap = jsonDecode(usuarioStr) as Map<String, dynamic>;
        _token = tokenSalvo;
        _usuario = Usuario.fromJson(usuarioMap);
        usuarioNotifier.value = _usuario;
        return true;
      }
    } catch (_) {
      // Caso haja dados corrompidos, limpa com segurança
      await encerrar();
    }
    return false;
  }

  /// Grava token e usuário no armazenamento local
  Future<void> _salvarNoDisco(String token, Usuario usuario) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chaveToken, token);
      await prefs.setString(_chaveUsuario, jsonEncode(usuario.toJson()));
    } catch (_) {}
  }

  /// Grava o nome preferido para o e-mail no armazenamento persistente para lembrar entre logins
  static Future<void> salvarNomeCustomizado(String email, String nome) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('landview_nome_${email.toLowerCase().trim()}', nome.trim());
    } catch (_) {}
  }

  /// Recupera o nome customizado do usuário caso já tenha sido alterado antes pelo usuário
  static Future<String?> obterNomeCustomizado(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final salvo = prefs.getString('landview_nome_${email.toLowerCase().trim()}');
      if (salvo != null && salvo.trim().isNotEmpty) return salvo.trim();
    } catch (_) {}
    return null;
  }

  /// Grava a grade detalhada de tamanhos e estoques individuais de um calçado no armazenamento local
  static Future<void> salvarGradeTamanhos(
    int calcadoId,
    List<MedidaTamanho> tamanhos,
  ) async {
    // Bloco protegido contra falhas de I/O no armazenamento local
    try {
      // Obtém a instância assíncrona do SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      // Converte a lista de instâncias MedidaTamanho em mapas JSON
      final listaJson = tamanhos.map((t) => t.toJson()).toList();
      // Grava a lista serializada como string JSON associada ao ID do calçado
      await prefs.setString(
        'landview_grade_$calcadoId',
        jsonEncode(listaJson),
      );
    // Ignora eventuais exceções silenciosamente
    } catch (_) {}
  }

  /// Recupera a grade detalhada de tamanhos salva no armazenamento local para este modelo
  static Future<List<MedidaTamanho>?> obterGradeTamanhos(int calcadoId) async {
    // Bloco protegido contra falhas de desserialização
    try {
      // Obtém a instância assíncrona do SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      // Recupera a string JSON associada à chave deste calçado
      final salvo = prefs.getString('landview_grade_$calcadoId');
      // Verifica se existe conteúdo salvo e não está em branco
      if (salvo != null && salvo.trim().isNotEmpty) {
        // Decodifica a string JSON em uma lista dinâmica
        final lista = jsonDecode(salvo);
        // Confere se a estrutura decodificada é de fato uma lista
        if (lista is List) {
          // Mapeia cada elemento da lista para um objeto MedidaTamanho
          return lista
              .map((e) => MedidaTamanho.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    // Ignora eventuais exceções silenciosamente
    } catch (_) {}
    // Retorna nulo caso não encontre nenhuma grade salva localmente
    return null;
  }

  /// Remove a grade salva de um calçado excluído do catálogo
  static Future<void> removerGradeTamanhos(int calcadoId) async {
    // Bloco protegido contra falhas de acesso
    try {
      // Obtém a instância assíncrona do SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      // Remove a chave de grade associada a este calçado
      await prefs.remove('landview_grade_$calcadoId');
    // Ignora eventuais exceções silenciosamente
    } catch (_) {}
  }

  /// Permite atualizar o nome de exibição do usuário na sessão sem exigir novo login
  void atualizarNome(String novoNome) {
    // Obtém o usuário atual
    final atual = _usuario;
    // Se não houver ninguém logado, interrompe
    if (atual == null) return;
    // Remove espaços em branco nas pontas
    final limpo = novoNome.trim();
    // Se o nome informado for vazio, interrompe
    if (limpo.isEmpty) return;
    // Atualiza a propriedade de nome mantendo os outros dados
    _usuario = atual.copyWith(nome: limpo);
    // Notifica a alteração aos ouvintes
    usuarioNotifier.value = _usuario;
    // Salva o nome associado a este e-mail no SharedPreferences
    salvarNomeCustomizado(atual.email, limpo);
    // Atualiza o registro salvo no armazenamento
    if (_token != null && _usuario != null) {
      _salvarNoDisco(_token!, _usuario!);
    }
  }

  /// Encerra a sessão atual limpando a memória, apagando o armazenamento local e avisando os ouvintes
  Future<void> encerrar() async {
    // Limpa o token da memória
    _token = null;
    // Limpa o usuário da memória
    _usuario = null;
    // Emite valor nulo aos ouvintes
    usuarioNotifier.value = null;

    // Remove as credenciais do armazenamento persistente
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chaveToken);
      await prefs.remove(_chaveUsuario);
    } catch (_) {}
  }

  /// Chamado automaticamente quando a API retorna erro 401: limpa a sessão e aciona o callback de navegação
  void expirar() {
    // Guarda se o usuário estava previamente autenticado
    final estavaLogado = logado;
    // Limpa as variáveis da sessão e o armazenamento
    encerrar();
    // Se estava logado, dispara a ação para redirecionar à tela de login com aviso de expiração
    if (estavaLogado) aoExpirar?.call();
  }
}
