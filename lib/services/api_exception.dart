/// Classe de exceção personalizada que padroniza todos os erros retornados pela API
/// ou pelas operações de rede, já com mensagens prontas para exibição na interface.
class ApiException implements Exception {
  /// Texto descritivo do erro que será mostrado diretamente para o usuário na tela
  final String mensagem;

  /// Código de status HTTP retornado pelo servidor (ex: 400, 401, 404, 409, 500)
  final int? status;

  /// Construtor que recebe a mensagem obrigatória e o código de status opcional
  ApiException(this.mensagem, {this.status});

  /// Sobrescreve o método toString para retornar diretamente a mensagem amigável
  @override
  String toString() => mensagem;
}
