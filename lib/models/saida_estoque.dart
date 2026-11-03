/// Um registro do histórico de saídas de estoque (`GET /stock-exit/`).
///
/// A API devolve só os IDs; [nomeProduto] e [emailUsuario] são preenchidos
/// pelo app para facilitar a leitura.
class SaidaEstoque {
  final int id;
  final int idProduto;
  final int idUsuario;
  final int idEstoque;
  final int quantidade;
  final String? nomeProduto;
  final String? emailUsuario;

  const SaidaEstoque({
    required this.id,
    required this.idProduto,
    required this.idUsuario,
    required this.idEstoque,
    required this.quantidade,
    this.nomeProduto,
    this.emailUsuario,
  });

  factory SaidaEstoque.fromJson(Map<String, dynamic> json) => SaidaEstoque(
        id: (json['id'] as num).toInt(),
        idProduto: (json['id_product'] as num).toInt(),
        idUsuario: (json['id_user'] as num).toInt(),
        idEstoque: (json['id_stock'] as num).toInt(),
        quantidade: (json['quantity'] as num).toInt(),
      );

  SaidaEstoque copyWith({String? nomeProduto, String? emailUsuario}) =>
      SaidaEstoque(
        id: id,
        idProduto: idProduto,
        idUsuario: idUsuario,
        idEstoque: idEstoque,
        quantidade: quantidade,
        nomeProduto: nomeProduto ?? this.nomeProduto,
        emailUsuario: emailUsuario ?? this.emailUsuario,
      );
}

