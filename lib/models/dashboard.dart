/// Modelo simplificado e enxuto de calçado utilizado especificamente nas tabelas e listas do Dashboard
/// (contendo apenas as propriedades essenciais para desempenho ágil de renderização).
class ItemDashboard {
  /// Identificador único do produto
  final int id;

  /// Nome comercial do calçado (ex: "Air Zoom Pegasus 40")
  final String nome;

  /// Marca fabricante do produto (ex: "Nike")
  final String marca;

  /// Quantidade acumulada de pares vendidos nos últimos 30 dias
  final int vendas;

  /// Quantidade física total de unidades disponíveis no estoque atual
  final int estoque;

  /// Construtor imutável com todos os campos necessários do item
  const ItemDashboard({
    // ID obrigatório
    required this.id,
    // Nome do calçado obrigatório
    required this.nome,
    // Marca obrigatória
    required this.marca,
    // Vendas em 30 dias obrigatórias
    required this.vendas,
    // Quantidade em estoque obrigatória
    required this.estoque,
  });

  /// Converte o mapa JSON vindo da API em uma instância de ItemDashboard
  factory ItemDashboard.fromJson(Map<String, dynamic> json) => ItemDashboard(
        // Converte o ID numérico para inteiro
        id: (json['id'] as num).toInt(),
        // Extrai o nome como String
        nome: json['nome'] as String,
        // Extrai a marca como String
        marca: json['marca'] as String,
        // Converte as vendas para inteiro, ou assume 0 se ausente
        vendas: (json['vendas'] as num?)?.toInt() ?? 0,
        // Converte o saldo de estoque para inteiro, ou assume 0 se ausente
        estoque: (json['estoque'] as num?)?.toInt() ?? 0,
      );
}

/// Agrupa os cartões de indicadores numéricos exibidos no topo do Dashboard da loja.
class ResumoDashboard {
  /// Quantidade total de modelos diferentes cadastrados no sistema
  final int totalModelos;

  /// Soma total de todas as unidades físicas de calçados guardadas no estoque
  final int unidadesEmEstoque;

  /// Soma total de pares vendidos somando todos os produtos nos últimos 30 dias
  final int vendas30Dias;

  /// Quantidade de produtos que estão com estoque crítico (menor ou igual ao limite baixo)
  final int modelosAcabando;

  /// Quantidade de produtos que estão com estoque em excesso (maior ou igual ao limite alto)
  final int modelosComExcesso;

  /// Ponto de corte numérico para considerar um estoque como "baixo" (padrão: 5 unidades)
  final int limiteEstoqueBaixo;

  /// Ponto de corte numérico para considerar um estoque como "em excesso" (padrão: 40 unidades)
  final int limiteEstoqueAlto;

  /// Construtor com valores numéricos obrigatórios e limites padrão pré-definidos
  const ResumoDashboard({
    // Total de modelos obrigatório
    required this.totalModelos,
    // Total de unidades físicas obrigatório
    required this.unidadesEmEstoque,
    // Total de vendas em 30 dias obrigatório
    required this.vendas30Dias,
    // Contagem de modelos acabando obrigatória
    required this.modelosAcabando,
    // Contagem de modelos em excesso obrigatória
    required this.modelosComExcesso,
    // Limite configurável para estoque baixo (default 5)
    this.limiteEstoqueBaixo = 5,
    // Limite configurável para excesso de estoque (default 40)
    this.limiteEstoqueAlto = 40,
  });

  /// Desserializa o JSON retornado para a estrutura de ResumoDashboard
  factory ResumoDashboard.fromJson(Map<String, dynamic> json) => ResumoDashboard(
        // Converte o total de modelos ou usa 0
        totalModelos: (json['total_modelos'] as num?)?.toInt() ?? 0,
        // Converte as unidades em estoque ou usa 0
        unidadesEmEstoque: (json['unidades_em_estoque'] as num?)?.toInt() ?? 0,
        // Converte o volume de vendas dos 30 dias ou usa 0
        vendas30Dias: (json['vendas_30_dias'] as num?)?.toInt() ?? 0,
        // Converte o total de modelos acabando ou usa 0
        modelosAcabando: (json['modelos_acabando'] as num?)?.toInt() ?? 0,
        // Converte o total de modelos em excesso ou usa 0
        modelosComExcesso: (json['modelos_com_excesso'] as num?)?.toInt() ?? 0,
        // Converte o limite de estoque baixo ou preserva 5
        limiteEstoqueBaixo: (json['limite_estoque_baixo'] as num?)?.toInt() ?? 5,
        // Converte o limite de excesso ou preserva 40
        limiteEstoqueAlto: (json['limite_estoque_alto'] as num?)?.toInt() ?? 40,
      );
}

/// Representa um produto em destaque de extremo de estoque (menor estoque ou maior estoque em tempo real),
/// mapeado diretamente da rota `GET /dashboard/` do backend FastAPI.
class ExtremoEstoque {
  /// Identificador do produto no banco de dados
  final int produtoId;

  /// Nome comercial do produto
  final String nome;

  /// Preço unitário cadastrado
  final double preco;

  /// Quantidade atual no estoque
  final int quantidade;

  /// Construtor imutável com os dados do extremo
  const ExtremoEstoque({
    // ID do produto obrigatório
    required this.produtoId,
    // Nome do produto obrigatório
    required this.nome,
    // Preço unitário obrigatório
    required this.preco,
    // Quantidade em estoque obrigatória
    required this.quantidade,
  });

  /// Construtor de fábrica para ler os campos literais retornados pela API FastAPI (`product_id`, `product_name`, etc.)
  factory ExtremoEstoque.fromJson(Map<String, dynamic> json) => ExtremoEstoque(
        // Converte 'product_id' para inteiro
        produtoId: (json['product_id'] as num).toInt(),
        // Extrai o nome do produto
        nome: json['product_name'] as String,
        // Converte 'unit_value' para double
        preco: (json['unit_value'] as num).toDouble(),
        // Converte 'quantity' para inteiro
        quantidade: (json['quantity'] as num).toInt(),
      );

  /// Método utilitário de segurança: converte apenas se o objeto for um Map válido, senão devolve nulo
  static ExtremoEstoque? talvez(dynamic json) =>
      json is Map<String, dynamic> ? ExtremoEstoque.fromJson(json) : null;
}

/// Modelo completo do Dashboard, combinando métricas consolidadas, rankings e destaques da API.
class Dashboard {
  /// Cartões de resumo geral do topo
  final ResumoDashboard resumo;

  /// Lista com o ranking dos calçados mais vendidos
  final List<ItemDashboard> maisVendidos;

  /// Lista com os calçados em situação de estoque baixo
  final List<ItemDashboard> estoqueBaixo;

  /// Lista com os calçados em situação de excesso de estoque
  final List<ItemDashboard> estoqueAlto;

  /// Destaque do produto com menor estoque retornado diretamente de `GET /dashboard/`
  final ExtremoEstoque? menorEstoque;

  /// Destaque do produto com maior estoque retornado diretamente de `GET /dashboard/`
  final ExtremoEstoque? maiorEstoque;

  /// Construtor com as seções principais do Dashboard
  const Dashboard({
    // Resumo numérico obrigatório
    required this.resumo,
    // Lista de mais vendidos obrigatória
    required this.maisVendidos,
    // Lista de estoque baixo obrigatória
    required this.estoqueBaixo,
    // Lista de estoque alto obrigatória
    required this.estoqueAlto,
    // Destaque de menor estoque opcional
    this.menorEstoque,
    // Destaque de maior estoque opcional
    this.maiorEstoque,
  });

  /// Permite atualizar apenas os dados de extremos (menor e maior estoque) sem reconstruir o dashboard inteiro
  Dashboard copyWith({
    ExtremoEstoque? menorEstoque,
    ExtremoEstoque? maiorEstoque,
  }) =>
      Dashboard(
        // Mantém o resumo existente
        resumo: resumo,
        // Mantém a lista de mais vendidos
        maisVendidos: maisVendidos,
        // Mantém a lista de estoque baixo
        estoqueBaixo: estoqueBaixo,
        // Mantém a lista de estoque alto
        estoqueAlto: estoqueAlto,
        // Atualiza o menor estoque ou mantém o atual
        menorEstoque: menorEstoque ?? this.menorEstoque,
        // Atualiza o maior estoque ou mantém o atual
        maiorEstoque: maiorEstoque ?? this.maiorEstoque,
      );

  /// Utilitário interno para converter listas genéricas de JSON para listas fortemente tipadas de ItemDashboard
  static List<ItemDashboard> _itens(dynamic valor) => ((valor as List?) ?? [])
      .map((e) => ItemDashboard.fromJson(e as Map<String, dynamic>))
      .toList();

  /// Construtor de fábrica para desserializar a resposta completa do Dashboard
  factory Dashboard.fromJson(Map<String, dynamic> json) => Dashboard(
        // Converte o objeto 'resumo'
        resumo: ResumoDashboard.fromJson(json['resumo'] as Map<String, dynamic>),
        // Converte a lista 'mais_vendidos'
        maisVendidos: _itens(json['mais_vendidos']),
        // Converte a lista 'estoque_baixo'
        estoqueBaixo: _itens(json['estoque_baixo']),
        // Converte a lista 'estoque_alto'
        estoqueAlto: _itens(json['estoque_alto']),
        // Lê com segurança o produto de menor estoque da API
        menorEstoque: ExtremoEstoque.talvez(json['lowest_stock']),
        // Lê com segurança o produto de maior estoque da API
        maiorEstoque: ExtremoEstoque.talvez(json['highest_stock']),
      );
}
