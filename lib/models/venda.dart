/// Representa o comprovante da operação de venda ou saída realizada,
/// trazendo o saldo de estoque atualizado imediatamente após a baixa.
class VendaRegistrada {
  /// Identificador único do registro da venda no sistema
  final int id;

  /// Identificador do calçado/produto que foi comercializado
  final int calcadoId;

  /// Quantidade de pares ou unidades que foram baixadas nesta operação
  final int quantidade;

  /// Saldo remanescente de unidades no estoque após a conclusão da baixa
  final int estoqueAtual;

  /// Data e horário exatos em que a venda foi confirmada no sistema (opcional)
  final DateTime? dataVenda;

  /// Construtor imutável que recebe os dados necessários da venda
  const VendaRegistrada({
    // ID obrigatório da venda
    required this.id,
    // ID do calçado obrigatório
    required this.calcadoId,
    // Quantidade vendida obrigatória
    required this.quantidade,
    // Estoque resultante obrigatório
    required this.estoqueAtual,
    // Carimbo de data/hora opcional
    this.dataVenda,
  });

  /// Converte a resposta em formato JSON retornada pelo backend em um objeto VendaRegistrada
  factory VendaRegistrada.fromJson(Map<String, dynamic> json) =>
      VendaRegistrada(
        // Converte o campo 'id' numérico para inteiro
        id: (json['id'] as num).toInt(),
        // Converte o campo 'calcado_id' numérico para inteiro
        calcadoId: (json['calcado_id'] as num).toInt(),
        // Converte a quantidade vendida para inteiro
        quantidade: (json['quantidade'] as num).toInt(),
        // Converte o saldo de estoque remanescente para inteiro
        estoqueAtual: (json['estoque_atual'] as num).toInt(),
        // Converte a string de data ISO 8601 para DateTime, ou mantém nulo se ausente
        dataVenda: json['data_venda'] == null
            ? null
            : DateTime.parse(json['data_venda'] as String),
      );
}
