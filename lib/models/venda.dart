class VendaRegistrada {
  final int id;
  final int calcadoId;
  final int quantidade;
  final int estoqueAtual;
  final DateTime? dataVenda;

  const VendaRegistrada({
    required this.id,
    required this.calcadoId,
    required this.quantidade,
    required this.estoqueAtual,
    this.dataVenda,
  });

  factory VendaRegistrada.fromJson(Map<String, dynamic> json) =>
      VendaRegistrada(
        id: (json['id'] as num).toInt(),
        calcadoId: (json['calcado_id'] as num).toInt(),
        quantidade: (json['quantidade'] as num).toInt(),
        estoqueAtual: (json['estoque_atual'] as num).toInt(),
        dataVenda: json['data_venda'] == null
            ? null
            : DateTime.parse(json['data_venda'] as String),
      );
}
