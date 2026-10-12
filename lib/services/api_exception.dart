/// Erro já traduzido para uma mensagem que pode ir direto para a tela.
class ApiException implements Exception {
  final String mensagem;
  final int? status;

  ApiException(this.mensagem, {this.status});

  @override
  String toString() => mensagem;
}
