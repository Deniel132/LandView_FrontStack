import 'dart:typed_data';

/// Tipo do calçado. O `valor` é exatamente o texto que a API usa no JSON.
enum TipoCalcado {
  tenis('tenis', 'Tênis'),
  chuteira('chuteira', 'Chuteira');

  final String valor;
  final String rotulo;
  const TipoCalcado(this.valor, this.rotulo);

  static TipoCalcado doValor(String? v) => TipoCalcado.values.firstWhere(
    (t) => t.valor == v,
    orElse: () => TipoCalcado.tenis,
  );
}

/// Forma do calçado: define se ele calça mais justo ou mais folgado
/// na largura. É o dado que o algoritmo em Python cruza com a medida do pé.
enum FormaCalcado {
  estreita('estreita', 'Estreita', 'Mais justo na largura do pé.'),
  padrao('padrao', 'Padrão', 'Largura convencional.'),
  larga('larga', 'Larga', 'Mais espaço na largura do pé.');

  final String valor;
  final String rotulo;
  final String descricao;
  const FormaCalcado(this.valor, this.rotulo, this.descricao);

  static FormaCalcado doValor(String? v) => FormaCalcado.values.firstWhere(
    (f) => f.valor == v,
    orElse: () => FormaCalcado.padrao,
  );
}

/// Uma linha da tabela de medidas: numeração e comprimento interno em cm.
class MedidaTamanho {
  final double numeracao;
  final double comprimentoCm;

  const MedidaTamanho({required this.numeracao, required this.comprimentoCm});

  factory MedidaTamanho.fromJson(Map<String, dynamic> json) => MedidaTamanho(
    numeracao: (json['numeracao'] as num).toDouble(),
    comprimentoCm: (json['comprimento_cm'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'numeracao': numeracao,
    'comprimento_cm': comprimentoCm,
  };
}

/// Modelo de calçado vendido pela loja (recurso do CRUD).
class Calcado {
  final int? id; // nulo até a API criar o registro
  final String nome;
  final String marca;
  final TipoCalcado tipo;
  final FormaCalcado forma;
  final double preco;
  final String? imagemUrl;
  // Bytes permitem pré-visualizar e reutilizar fotos locais no modo demo.
  final Uint8List? imagemBytes;
  final int estoque; // unidades disponíveis
  final List<MedidaTamanho> tamanhos;

  const Calcado({
    this.id,
    required this.nome,
    required this.marca,
    required this.tipo,
    required this.forma,
    required this.preco,
    this.imagemUrl,
    this.imagemBytes,
    this.estoque = 0,
    this.tamanhos = const [],
  });

  bool get temImagem =>
      imagemBytes != null ||
      (imagemUrl != null && imagemUrl!.trim().isNotEmpty);

  bool get temImagemUrl => imagemUrl != null && imagemUrl!.trim().isNotEmpty;

  Calcado copyWith({int? estoque}) => Calcado(
    id: id,
    nome: nome,
    marca: marca,
    tipo: tipo,
    forma: forma,
    preco: preco,
    imagemUrl: imagemUrl,
    imagemBytes: imagemBytes,
    estoque: estoque ?? this.estoque,
    tamanhos: tamanhos,
  );

  factory Calcado.fromJson(Map<String, dynamic> json) {
    final tabela =
        ((json['tamanhos'] as List?) ?? [])
            .map((e) => MedidaTamanho.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.numeracao.compareTo(b.numeracao));

    return Calcado(
      id: json['id'] as int?,
      nome: json['nome'] as String,
      marca: json['marca'] as String,
      tipo: TipoCalcado.doValor(json['tipo'] as String?),
      forma: FormaCalcado.doValor(json['forma'] as String?),
      preco: (json['preco'] as num).toDouble(),
      imagemUrl: json['imagem_url'] as String?,
      estoque: (json['estoque'] as num?)?.toInt() ?? 0,
      tamanhos: tabela,
    );
  }

  /// Corpo enviado em POST/PUT. O `id` não vai: ele vem da URL.
  Map<String, dynamic> toJson() => {
    'nome': nome,
    'marca': marca,
    'tipo': tipo.valor,
    'forma': forma.valor,
    'preco': preco,
    'imagem_url': temImagemUrl ? imagemUrl!.trim() : null,
    'estoque': estoque,
    'tamanhos': tamanhos.map((t) => t.toJson()).toList(),
  };
}
