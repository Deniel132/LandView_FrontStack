import 'dart:convert';
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

/// Uma linha da tabela de medidas: numeração, comprimento interno em cm
/// e quantidade individual disponível naquele tamanho.
class MedidaTamanho {
  final double numeracao;
  final double comprimentoCm;
  final int? estoque;

  const MedidaTamanho({
    required this.numeracao,
    required this.comprimentoCm,
    this.estoque,
  });

  MedidaTamanho copyWith({
    double? numeracao,
    double? comprimentoCm,
    int? estoque,
  }) => MedidaTamanho(
    numeracao: numeracao ?? this.numeracao,
    comprimentoCm: comprimentoCm ?? this.comprimentoCm,
    estoque: estoque ?? this.estoque,
  );

  factory MedidaTamanho.fromJson(Map<String, dynamic> json) => MedidaTamanho(
    numeracao: (json['numeracao'] as num).toDouble(),
    comprimentoCm: (json['comprimento_cm'] as num).toDouble(),
    estoque: (json['estoque'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'numeracao': numeracao,
    'comprimento_cm': comprimentoCm,
    if (estoque != null) 'estoque': estoque,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedidaTamanho &&
          other.numeracao == numeracao &&
          other.comprimentoCm == comprimentoCm &&
          other.estoque == estoque;

  @override
  int get hashCode => Object.hash(numeracao, comprimentoCm, estoque);
}

/// Modelo de calçado gerenciado no controle de estoque.
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
  final int estoque; // unidades totais disponíveis
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

  bool get esgotado => estoque <= 0;
  bool get estoqueBaixo => estoque > 0 && estoque <= 5;
  bool get estoqueAlto => estoque >= 40;

  double get valorTotalEstoque => preco * estoque;

  /// Retorna a grade com a quantidade individual de cada numeração sincronizada
  /// com o estoque total do calçado.
  List<MedidaTamanho> get tamanhosComEstoque {
    if (tamanhos.isEmpty) return const [];
    final totalAlvo = estoque < 0 ? 0 : estoque;
    final temEstoqueIndividual = tamanhos.any((t) => t.estoque != null);

    if (!temEstoqueIndividual) {
      final base = totalAlvo ~/ tamanhos.length;
      final resto = totalAlvo % tamanhos.length;
      return [
        for (var i = 0; i < tamanhos.length; i++)
          tamanhos[i].copyWith(estoque: base + (i < resto ? 1 : 0)),
      ];
    }

    final qtds = [
      for (final t in tamanhos) (t.estoque ?? 0) < 0 ? 0 : (t.estoque ?? 0),
    ];
    var soma = qtds.fold<int>(0, (s, v) => s + v);

    if (soma < totalAlvo) {
      var falta = totalAlvo - soma;
      var idx = 0;
      while (falta > 0) {
        qtds[idx % qtds.length]++;
        falta--;
        idx++;
      }
    } else if (soma > totalAlvo) {
      var excesso = soma - totalAlvo;
      var idx = qtds.length - 1;
      while (excesso > 0 && qtds.any((q) => q > 0)) {
        final pos = idx % qtds.length;
        if (qtds[pos] > 0) {
          qtds[pos]--;
          excesso--;
        }
        idx--;
        if (idx < 0) idx = qtds.length - 1;
      }
    }

    return [
      for (var i = 0; i < tamanhos.length; i++)
        tamanhos[i].copyWith(estoque: qtds[i]),
    ];
  }

  /// Quantidade de numerações que possuem pelo menos 1 par em estoque.
  int get totalTamanhosDisponiveis =>
      tamanhosComEstoque.where((t) => (t.estoque ?? 0) > 0).length;

  /// Numerações que estão zeradas na grade.
  List<MedidaTamanho> get tamanhosZerados =>
      tamanhosComEstoque.where((t) => (t.estoque ?? 0) == 0).toList();

  /// Atualiza a quantidade de uma numeração específica e recalcula o total.
  Calcado atualizarEstoqueDoTamanho(double numeracao, int novaQuantidade) {
    final qtdLimpa = novaQuantidade < 0 ? 0 : novaQuantidade;
    final novaGrade = [
      for (final t in tamanhosComEstoque)
        if (t.numeracao == numeracao)
          t.copyWith(estoque: qtdLimpa)
        else
          t,
    ];
    final novoTotal = novaGrade.fold<int>(0, (s, t) => s + (t.estoque ?? 0));
    return copyWith(estoque: novoTotal, tamanhos: novaGrade);
  }

  /// Desconta unidades de uma numeração específica (e o excedente das demais, se houver).
  Calcado descontarDoTamanho(double? numeracao, int quantidadeBaixa) {
    final grade = [...tamanhosComEstoque];
    if (grade.isEmpty) {
      final novoEstoque = (estoque - quantidadeBaixa).clamp(0, 999999);
      return copyWith(estoque: novoEstoque);
    }

    var restante = quantidadeBaixa;
    if (numeracao != null) {
      final idx = grade.indexWhere((t) => t.numeracao == numeracao);
      if (idx != -1) {
        final disp = grade[idx].estoque ?? 0;
        final abater = restante <= disp ? restante : disp;
        grade[idx] = grade[idx].copyWith(estoque: disp - abater);
        restante -= abater;
      }
    }

    for (var i = 0; i < grade.length && restante > 0; i++) {
      final disp = grade[i].estoque ?? 0;
      if (disp > 0) {
        final abater = restante <= disp ? restante : disp;
        grade[i] = grade[i].copyWith(estoque: disp - abater);
        restante -= abater;
      }
    }

    final novoTotal = grade.fold<int>(0, (s, t) => s + (t.estoque ?? 0));
    return copyWith(estoque: novoTotal, tamanhos: grade);
  }

  Calcado copyWith({
    int? id,
    String? nome,
    String? marca,
    TipoCalcado? tipo,
    FormaCalcado? forma,
    double? preco,
    String? imagemUrl,
    Uint8List? imagemBytes,
    int? estoque,
    List<MedidaTamanho>? tamanhos,
  }) => Calcado(
    id: id ?? this.id,
    nome: nome ?? this.nome,
    marca: marca ?? this.marca,
    tipo: tipo ?? this.tipo,
    forma: forma ?? this.forma,
    preco: preco ?? this.preco,
    imagemUrl: imagemUrl ?? this.imagemUrl,
    imagemBytes: imagemBytes ?? this.imagemBytes,
    estoque: estoque ?? this.estoque,
    tamanhos: tamanhos ?? this.tamanhos,
  );

  factory Calcado.fromJson(Map<String, dynamic> json) {
    final tabela =
        ((json['tamanhos'] as List?) ?? [])
            .map((e) => MedidaTamanho.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.numeracao.compareTo(b.numeracao));

    final rawUrl = json['imagem_url'] as String?;
    Uint8List? bytes;
    if (rawUrl != null && rawUrl.startsWith('data:image')) {
      final idx = rawUrl.indexOf('base64,');
      if (idx != -1) {
        try {
          bytes = base64Decode(rawUrl.substring(idx + 7));
        } catch (_) {}
      }
    }

    return Calcado(
      id: json['id'] as int?,
      nome: json['nome'] as String,
      marca: json['marca'] as String,
      tipo: TipoCalcado.doValor(json['tipo'] as String?),
      forma: FormaCalcado.doValor(json['forma'] as String?),
      preco: (json['preco'] as num).toDouble(),
      imagemUrl: rawUrl,
      imagemBytes: bytes,
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
