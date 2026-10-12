import 'package:flutter/foundation.dart';
import '../models/usuario.dart';

/// Guarda quem está logado e o token JWT, só em memória: ao fechar o app,
/// o login é pedido de novo. (Para lembrar o login seria preciso persistir
/// o token, por exemplo com o pacote flutter_secure_storage.)
class Sessao {
  Sessao._();
  static final Sessao instance = Sessao._();

  String? _token;
  Usuario? _usuario;

  /// Chamado quando a API recusa o token (401). O `main.dart` o usa
  /// para devolver o usuário à tela de login.
  VoidCallback? aoExpirar;

  bool get logado => _token != null;
  String? get token => _token;
  Usuario? get usuario => _usuario;

  void iniciar(String token, Usuario usuario) {
    _token = token;
    _usuario = usuario;
  }

  void encerrar() {
    _token = null;
    _usuario = null;
  }

  /// Sessão invalidada pelo servidor: limpa e avisa o app (uma única vez).
  void expirar() {
    final estavaLogado = logado;
    encerrar();
    if (estavaLogado) aoExpirar?.call();
  }
}
