/// Modelo resumido usado nas listas do painel (não é o calçado completo).
class ItemDashboard {
  final int id;
  final String nome;
  final String marca;
  final int vendas; // vendas nos últimos 30 dias
  final int estoque;

  const ItemDashboard({
    required this.id,
    required this.nome,
    required this.marca,
    required this.vendas,
    required this.estoque,
  });

  factory ItemDashboard.fromJson(Map<String, dynamic> json) => ItemDashboard(
        id: (json['id'] as num).toInt(),
        nome: json['nome'] as String,
        marca: json['marca'] as String,
        vendas: (json['vendas'] as num?)?.toInt() ?? 0,
        estoque: (json['estoque'] as num?)?.toInt() ?? 0,
      );
}

/// Números do topo do painel + os limites usados para classificar o estoque.
class ResumoDashboard {
  final int totalModelos;
  final int unidadesEmEstoque;
  final int vendas30Dias;
  final int modelosAcabando;
  final int modelosComExcesso;
  final int limiteEstoqueBaixo; // até este valor = "acabando"
  final int limiteEstoqueAlto; // a partir deste valor = "excesso"

  const ResumoDashboard({
    required this.totalModelos,
    required this.unidadesEmEstoque,
    required this.vendas30Dias,
    required this.modelosAcabando,
    required this.modelosComExcesso,
    this.limiteEstoqueBaixo = 5,
    this.limiteEstoqueAlto = 40,
  });

  factory ResumoDashboard.fromJson(Map<String, dynamic> json) => ResumoDashboard(
        totalModelos: (json['total_modelos'] as num?)?.toInt() ?? 0,
        unidadesEmEstoque: (json['unidades_em_estoque'] as num?)?.toInt() ?? 0,
        vendas30Dias: (json['vendas_30_dias'] as num?)?.toInt() ?? 0,
        modelosAcabando: (json['modelos_acabando'] as num?)?.toInt() ?? 0,
        modelosComExcesso: (json['modelos_com_excesso'] as num?)?.toInt() ?? 0,
        limiteEstoqueBaixo: (json['limite_estoque_baixo'] as num?)?.toInt() ?? 5,
        limiteEstoqueAlto: (json['limite_estoque_alto'] as num?)?.toInt() ?? 40,
      );
}

/// Produto com menor ou maior estoque, vindo de `GET /dashboard/` da API.
class ExtremoEstoque {
  final int produtoId;
  final String nome;
  final double preco;
  final int quantidade;

  const ExtremoEstoque({
    required this.produtoId,
    required this.nome,
    required this.preco,
    required this.quantidade,
  });

  factory ExtremoEstoque.fromJson(Map<String, dynamic> json) => ExtremoEstoque(
        produtoId: (json['product_id'] as num).toInt(),
        nome: json['product_name'] as String,
        preco: (json['unit_value'] as num).toDouble(),
        quantidade: (json['quantity'] as num).toInt(),
      );

  static ExtremoEstoque? talvez(dynamic json) =>
      json is Map<String, dynamic> ? ExtremoEstoque.fromJson(json) : null;
}

/// Painel da loja: indicadores calculados pelo app + destaques da API.
class Dashboard {
  final ResumoDashboard resumo;
  final List<ItemDashboard> maisVendidos;
  final List<ItemDashboard> estoqueBaixo;
  final List<ItemDashboard> estoqueAlto;

  /// `lowest_stock` e `highest_stock` de `GET /dashboard/`. Ficam nulos se a
  /// rota não responder (o restante do painel continua funcionando).
  final ExtremoEstoque? menorEstoque;
  final ExtremoEstoque? maiorEstoque;

  const Dashboard({
    required this.resumo,
    required this.maisVendidos,
    required this.estoqueBaixo,
    required this.estoqueAlto,
    this.menorEstoque,
    this.maiorEstoque,
  });

  Dashboard copyWith({
    ExtremoEstoque? menorEstoque,
    ExtremoEstoque? maiorEstoque,
  }) =>
      Dashboard(
        resumo: resumo,
        maisVendidos: maisVendidos,
        estoqueBaixo: estoqueBaixo,
        estoqueAlto: estoqueAlto,
        menorEstoque: menorEstoque ?? this.menorEstoque,
        maiorEstoque: maiorEstoque ?? this.maiorEstoque,
      );

  static List<ItemDashboard> _itens(dynamic valor) => ((valor as List?) ?? [])
      .map((e) => ItemDashboard.fromJson(e as Map<String, dynamic>))
      .toList();

  factory Dashboard.fromJson(Map<String, dynamic> json) => Dashboard(
        resumo: ResumoDashboard.fromJson(json['resumo'] as Map<String, dynamic>),
        maisVendidos: _itens(json['mais_vendidos']),
        estoqueBaixo: _itens(json['estoque_baixo']),
        estoqueAlto: _itens(json['estoque_alto']),
        menorEstoque: ExtremoEstoque.talvez(json['lowest_stock']),
        maiorEstoque: ExtremoEstoque.talvez(json['highest_stock']),
      );
}
