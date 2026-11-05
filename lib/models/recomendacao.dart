/// Modelo que encapsula o resultado do cálculo do provador virtual (recomendação de numeração),
/// processado pelo algoritmo do backend ou pela camada de demonstração em memória.
///
/// Segue rigorosamente os nomes e formatos definidos em `API_CONTRATO.md`.
class Recomendacao {
  /// Numeração principal recomendada para o pé informado (ex: 41.0)
  final double tamanho;

  /// Segunda opção de numeração sugerida caso o cliente prefira um calce mais folgado (opcional)
  final double? alternativa;

  /// Folga restante estimada em centímetros entre a ponta do dedo e a ponta da palmilha (opcional)
  final double? folgaCm;

  /// Texto explicativo gerado pelo sistema justificando a escolha e orientando o cliente/vendedor
  final String observacao;

  /// Construtor padrão que inicializa todos os atributos da recomendação
  const Recomendacao({
    // Numeração recomendada obrigatória
    required this.tamanho,
    // Numeração alternativa opcional
    this.alternativa,
    // Medida da folga em centímetros opcional
    this.folgaCm,
    // Mensagem de observação com valor padrão de texto vazio
    this.observacao = '',
  });

  /// Construtor de fábrica (factory) que desserializa o mapa JSON retornado pela API em uma instância tipada
  factory Recomendacao.fromJson(Map<String, dynamic> json) => Recomendacao(
        // Converte o campo 'tamanho_recomendado' do JSON para double
        tamanho: (json['tamanho_recomendado'] as num).toDouble(),
        // Converte o campo opcional 'alternativa' para double caso exista
        alternativa: (json['alternativa'] as num?)?.toDouble(),
        // Converte o campo opcional 'folga_cm' para double caso exista
        folgaCm: (json['folga_cm'] as num?)?.toDouble(),
        // Extrai a mensagem de observação ou utiliza texto vazio se for nulo
        observacao: (json['observacao'] as String?) ?? '',
      );
}
