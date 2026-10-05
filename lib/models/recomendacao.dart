/// Resultado de recomendação calculado no backend Python e devolvido pela API.
///
/// Os nomes de campos JSON correspondem à resposta documentada em
/// `API_CONTRATO.md`.
class Recomendacao {
  final double tamanho;
  final double? alternativa;
  final double? folgaCm;
  final String observacao;

  const Recomendacao({
    required this.tamanho,
    this.alternativa,
    this.folgaCm,
    this.observacao = '',
  });

  factory Recomendacao.fromJson(Map<String, dynamic> json) => Recomendacao(
        tamanho: (json['tamanho_recomendado'] as num).toDouble(),
        alternativa: (json['alternativa'] as num?)?.toDouble(),
        folgaCm: (json['folga_cm'] as num?)?.toDouble(),
        observacao: (json['observacao'] as String?) ?? '',
      );
}
