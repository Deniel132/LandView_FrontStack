// Importa a biblioteca para manipulação e decodificação de Base64
import 'dart:convert';
// Importa o tipo Uint8List para armazenamento e manipulação de bytes brutos da imagem
import 'dart:typed_data';

/// Define a categoria esportiva do calçado (Tênis casual/corrida ou Chuteira de campo/futsal).
/// A propriedade `valor` corresponde exatamente ao texto esperado no JSON pela API.
enum TipoCalcado {
  // Tênis convencional com rótulo amigável
  tenis('tenis', 'Tênis'),
  // Chuteira com rótulo amigável
  chuteira('chuteira', 'Chuteira');

  // Texto técnico persistido no banco de dados e tráfego JSON
  final String valor;
  // Nome legível exibido nas telas para os vendedores
  final String rotulo;

  // Construtor do enum
  const TipoCalcado(this.valor, this.rotulo);

  /// Converte uma String da API para o enum correspondente (assume 'tenis' caso não encontre)
  static TipoCalcado doValor(String? v) => TipoCalcado.values.firstWhere(
    (t) => t.valor == v,
    orElse: () => TipoCalcado.tenis,
  );
}

/// Define a largura do formato interno do calçado (estreita, padrão ou larga).
/// Essa informação é crucial para o algoritmo do provador virtual compensar a folga do pé.
enum FormaCalcado {
  // Forma estreita: calce mais justo e ajustado
  estreita('estreita', 'Estreita', 'Mais justo na largura do pé.'),
  // Forma padrão: calce de largura convencional
  padrao('padrao', 'Padrão', 'Largura convencional.'),
  // Forma larga: formato com mais espaço nas laterais dos dedos
  larga('larga', 'Larga', 'Mais espaço na largura do pé.');

  // Identificador textual da forma no JSON
  final String valor;
  // Nome legível para a interface do usuário
  final String rotulo;
  // Explicação complementar para guiar o cliente na escolha
  final String descricao;

  // Construtor do enum de forma
  const FormaCalcado(this.valor, this.rotulo, this.descricao);

  /// Converte uma String para a FormaCalcado correspondente (assume 'padrao' se nulo ou inválido)
  static FormaCalcado doValor(String? v) => FormaCalcado.values.firstWhere(
    (f) => f.valor == v,
    orElse: () => FormaCalcado.padrao,
  );
}

/// Representa uma linha na grade de tamanhos do calçado: a numeração comercial (ex: 41),
/// o comprimento da palmilha interna em centímetros (ex: 27.5 cm) e a quantidade em estoque para aquele número.
class MedidaTamanho {
  /// Numeração brasileira do calçado (ex: 39.0, 40.0)
  final double numeracao;

  /// Medida real interna da palmilha em centímetros
  final double comprimentoCm;

  /// Quantidade de pares disponíveis exclusivamente para esta numeração
  final int? estoque;

  /// Construtor imutável da medida de tamanho
  const MedidaTamanho({
    // Numeração obrigatória
    required this.numeracao,
    // Comprimento interno obrigatório
    required this.comprimentoCm,
    // Estoque individual opcional
    this.estoque,
  });

  /// Gera uma cópia da medida permitindo alterar campos específicos
  MedidaTamanho copyWith({
    double? numeracao,
    double? comprimentoCm,
    int? estoque,
  }) => MedidaTamanho(
    // Atualiza numeração ou preserva atual
    numeracao: numeracao ?? this.numeracao,
    // Atualiza comprimento ou preserva atual
    comprimentoCm: comprimentoCm ?? this.comprimentoCm,
    // Atualiza estoque individual ou preserva atual
    estoque: estoque ?? this.estoque,
  );

  /// Converte um mapa JSON para um objeto MedidaTamanho
  factory MedidaTamanho.fromJson(Map<String, dynamic> json) => MedidaTamanho(
    // Converte numeração numérica para double
    numeracao: (json['numeracao'] as num).toDouble(),
    // Converte comprimento em centímetros para double
    comprimentoCm: (json['comprimento_cm'] as num).toDouble(),
    // Converte estoque individual para int opcional
    estoque: (json['estoque'] as num?)?.toInt(),
  );

  /// Serializa a medida de tamanho para o formato JSON
  Map<String, dynamic> toJson() => {
    // Grava a numeração
    'numeracao': numeracao,
    // Grava o comprimento
    'comprimento_cm': comprimentoCm,
    // Grava o estoque individual caso não seja nulo
    if (estoque != null) 'estoque': estoque,
  };

  /// Sobrescreve o operador de igualdade para comparação por valor e integridade nos testes
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedidaTamanho &&
          other.numeracao == numeracao &&
          other.comprimentoCm == comprimentoCm &&
          other.estoque == estoque;

  /// Gera o código hash compatível com o operador de igualdade
  @override
  int get hashCode => Object.hash(numeracao, comprimentoCm, estoque);
}

/// Modelo principal de Calçado gerenciado pelo sistema de estoque e catálogo.
class Calcado {
  /// Identificador único gerado pelo banco de dados (nulo antes do primeiro salvamento)
  final int? id;

  /// Nome comercial do calçado (ex: "Mercurial Vapor 15 Academy")
  final String nome;

  /// Marca do fabricante (ex: "Nike", "Adidas", "Puma")
  final String marca;

  /// Categoria esportiva (Tênis ou Chuteira)
  final TipoCalcado tipo;

  /// Largura da forma (Estreita, Padrão ou Larga)
  final FormaCalcado forma;

  /// Preço unitário de venda em reais (BRL)
  final double preco;

  /// URL de rede ou string Base64 da foto do calçado
  final String? imagemUrl;

  /// Bytes da imagem em memória RAM para visualização instantânea em testes e modo demo
  final Uint8List? imagemBytes;

  /// Total consolidado de unidades físicas disponíveis no estoque
  final int estoque;

  /// Grade de medidas e tamanhos disponíveis para este modelo
  final List<MedidaTamanho> tamanhos;

  /// Quantidade de vendas em 30 dias (usado pelo dashboard e mock)
  final int vendas30Dias;

  /// Construtor imutável com validações e valores padrão
  const Calcado({
    // ID opcional (atribuído pelo banco)
    this.id,
    // Nome do calçado obrigatório
    required this.nome,
    // Marca obrigatória
    required this.marca,
    // Categoria do calçado obrigatória
    required this.tipo,
    // Forma do calçado obrigatória
    required this.forma,
    // Preço de venda obrigatório
    required this.preco,
    // URL da imagem opcional
    this.imagemUrl,
    // Bytes de imagem opcionais
    this.imagemBytes,
    // Estoque com valor padrão zero
    this.estoque = 0,
    // Grade de tamanhos padrão vazia
    this.tamanhos = const [],
    // Vendas em 30 dias com valor padrão zero
    this.vendas30Dias = 0,
  });

  /// Indica se o calçado possui alguma imagem cadastrada (seja por bytes em memória ou por URL segura)
  bool get temImagem => imagemBytes != null || temImagemUrl;

  /// Indica se possui uma URL de imagem válida, não vazia e com protocolo seguro (http, https ou data:image/)
  bool get temImagemUrl {
    // Recupera a string da URL removendo espaços nas extremidades
    final u = imagemUrl?.trim().toLowerCase();
    // Se for nula ou vazia, retorna falso
    if (u == null || u.isEmpty) return false;
    // Aceita apenas protocolos seguros de imagem (evita esquemas maliciosos como javascript:)
    return u.startsWith('http://') ||
        u.startsWith('https://') ||
        u.startsWith('data:image/');
  }

  /// Indica se o calçado está com estoque zerado ou esgotado
  bool get esgotado => estoque <= 0;

  /// Indica se o calçado está em nível crítico de estoque (entre 1 e 5 unidades)
  bool get estoqueBaixo => estoque > 0 && estoque <= 5;

  /// Indica se o calçado possui excesso de estoque (40 unidades ou mais)
  bool get estoqueAlto => estoque >= 40;

  /// Calcula o valor monetário total imobilizado no estoque deste calçado (Preço x Quantidade)
  double get valorTotalEstoque => preco * estoque;

  /// Retorna a grade com a quantidade individual de cada numeração sincronizada com o estoque total.
  /// Se o produto não tiver contagem individual por número, distribui uniformemente as unidades.
  List<MedidaTamanho> get tamanhosComEstoque {
    // Se a tabela de tamanhos estiver vazia, retorna lista vazia
    if (tamanhos.isEmpty) return const [];
    // Garante que o total não seja negativo
    final totalAlvo = estoque < 0 ? 0 : estoque;
    // Verifica se algum tamanho já possui estoque individual preenchido
    final temEstoqueIndividual = tamanhos.any((t) => t.estoque != null);

    // Se nenhum tamanho possuir estoque individual, faz distribuição matemática automática
    if (!temEstoqueIndividual) {
      // Divide a quantidade base igualmente pelo número de tamanhos da grade
      final base = totalAlvo ~/ tamanhos.length;
      // Calcula o resto da divisão para distribuir o excedente
      final resto = totalAlvo % tamanhos.length;
      return [
        // Itera sobre cada tamanho atribuindo a quantidade calculada
        for (var i = 0; i < tamanhos.length; i++)
          tamanhos[i].copyWith(estoque: base + (i < resto ? 1 : 0)),
      ];
    }

    // Cria a lista de quantidades individuais tratando nulos como zero
    final qtds = [
      for (final t in tamanhos) (t.estoque ?? 0) < 0 ? 0 : (t.estoque ?? 0),
    ];
    // Soma todas as quantidades individuais
    var soma = qtds.fold<int>(0, (s, v) => s + v);

    // Se a soma individual for menor que o estoque total, distribui o restante nos primeiros tamanhos
    if (soma < totalAlvo) {
      var falta = totalAlvo - soma;
      var idx = 0;
      while (falta > 0) {
        qtds[idx % qtds.length]++;
        falta--;
        idx++;
      }
    // Se a soma individual for maior que o estoque total, reduz o excedente a partir dos últimos tamanhos
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

    // Retorna a grade de tamanhos atualizada com as quantidades individuais sincronizadas
    return [
      for (var i = 0; i < tamanhos.length; i++)
        tamanhos[i].copyWith(estoque: qtds[i]),
    ];
  }

  /// Quantidade de numerações diferentes que possuem pelo menos 1 unidade disponível
  int get totalTamanhosDisponiveis =>
      tamanhosComEstoque.where((t) => (t.estoque ?? 0) > 0).length;

  /// Retorna apenas a lista de tamanhos que estão completamente esgotados na grade
  List<MedidaTamanho> get tamanhosZerados =>
      tamanhosComEstoque.where((t) => (t.estoque ?? 0) == 0).toList();

  /// Atualiza a quantidade disponível de uma numeração específica e recalcula o total do estoque
  Calcado atualizarEstoqueDoTamanho(double numeracao, int novaQuantidade) {
    // Garante que a quantidade não seja negativa
    final qtdLimpa = novaQuantidade < 0 ? 0 : novaQuantidade;
    // Substitui a quantidade apenas na numeração solicitada
    final novaGrade = [
      for (final t in tamanhosComEstoque)
        if (t.numeracao == numeracao)
          t.copyWith(estoque: qtdLimpa)
        else
          t,
    ];
    // Recalcula o estoque total somando as quantidades de todos os tamanhos da grade
    final novoTotal = novaGrade.fold<int>(0, (s, t) => s + (t.estoque ?? 0));
    // Retorna o calçado com o novo total e a nova grade de tamanhos
    return copyWith(estoque: novoTotal, tamanhos: novaGrade);
  }

  /// Desconta unidades de uma numeração específica durante uma venda
  Calcado descontarDoTamanho(double? numeracao, int quantidadeBaixa) {
    // Clona a grade de tamanhos com estoques atuais
    final grade = [...tamanhosComEstoque];
    // Se a grade estiver vazia, apenas abate do estoque total sem permitir negativo
    if (grade.isEmpty) {
      final novoEstoque = (estoque - quantidadeBaixa).clamp(0, 999999);
      return copyWith(estoque: novoEstoque);
    }

    // Quantidade que ainda precisa ser abatida
    var restante = quantidadeBaixa;

    // Se uma numeração específica foi selecionada na venda, abate primeiro dela
    if (numeracao != null) {
      final idx = grade.indexWhere((t) => t.numeracao == numeracao);
      if (idx != -1) {
        final disp = grade[idx].estoque ?? 0;
        final abater = restante <= disp ? restante : disp;
        grade[idx] = grade[idx].copyWith(estoque: disp - abater);
        restante -= abater;
      }
    }

    // Se ainda restar quantidade para abater, desconta dos outros tamanhos que possuem saldo
    for (var i = 0; i < grade.length && restante > 0; i++) {
      final disp = grade[i].estoque ?? 0;
      if (disp > 0) {
        final abater = restante <= disp ? restante : disp;
        grade[i] = grade[i].copyWith(estoque: disp - abater);
        restante -= abater;
      }
    }

    // Recalcula o total somando a nova grade
    final novoTotal = grade.fold<int>(0, (s, t) => s + (t.estoque ?? 0));
    // Retorna a cópia atualizada
    return copyWith(estoque: novoTotal, tamanhos: grade);
  }

  /// Retorna uma nova instância de Calçado substituindo apenas os parâmetros passados
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
    int? vendas30Dias,
  }) => Calcado(
    // Atualiza ID ou mantém o atual
    id: id ?? this.id,
    // Atualiza nome ou mantém o atual
    nome: nome ?? this.nome,
    // Atualiza marca ou mantém a atual
    marca: marca ?? this.marca,
    // Atualiza tipo ou mantém o atual
    tipo: tipo ?? this.tipo,
    // Atualiza forma ou mantém a atual
    forma: forma ?? this.forma,
    // Atualiza preço ou mantém o atual
    preco: preco ?? this.preco,
    // Atualiza URL de imagem ou mantém a atual
    imagemUrl: imagemUrl ?? this.imagemUrl,
    // Atualiza bytes de imagem ou mantém os atuais
    imagemBytes: imagemBytes ?? this.imagemBytes,
    // Atualiza estoque ou mantém o atual
    estoque: estoque ?? this.estoque,
    // Atualiza grade de tamanhos ou mantém a atual
    tamanhos: tamanhos ?? this.tamanhos,
    // Atualiza vendas em 30 dias ou mantém as atuais
    vendas30Dias: vendas30Dias ?? this.vendas30Dias,
  );

  /// Construtor de fábrica para criar uma instância de Calçado a partir de um Map JSON
  factory Calcado.fromJson(Map<String, dynamic> json) {
    // Converte a lista de tamanhos JSON para uma lista ordenada de MedidaTamanho
    final tabela =
        ((json['tamanhos'] as List?) ?? [])
            .map((e) => MedidaTamanho.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.numeracao.compareTo(b.numeracao));

    // Obtém a URL da imagem informada
    final rawUrl = json['imagem_url'] as String?;
    Uint8List? bytes;

    // Se a URL for uma string Base64 embutida, decodifica diretamente para bytes
    if (rawUrl != null && rawUrl.startsWith('data:image')) {
      final idx = rawUrl.indexOf('base64,');
      if (idx != -1) {
        try {
          bytes = base64Decode(rawUrl.substring(idx + 7));
        } catch (_) {}
      }
    }

    // Retorna a instância completa do Calçado desserializada
    return Calcado(
      // ID do produto
      id: json['id'] as int?,
      // Nome do produto
      nome: json['nome'] as String,
      // Marca do produto
      marca: json['marca'] as String,
      // Categoria mapeada via enum
      tipo: TipoCalcado.doValor(json['tipo'] as String?),
      // Forma mapeada via enum
      forma: FormaCalcado.doValor(json['forma'] as String?),
      // Preço convertido para double
      preco: (json['preco'] as num).toDouble(),
      // URL original da imagem
      imagemUrl: rawUrl,
      // Bytes decodificados da imagem
      imagemBytes: bytes,
      // Estoque total
      estoque: (json['estoque'] as num?)?.toInt() ?? 0,
      // Grade de tamanhos ordenada
      tamanhos: tabela,
      // Vendas em 30 dias
      vendas30Dias: (json['vendas_30_dias'] as num?)?.toInt() ?? 0,
    );
  }

  /// Serializa a entidade de Calçado para o corpo JSON utilizado em requisições POST e PUT
  Map<String, dynamic> toJson() => {
    // Grava o nome
    'nome': nome,
    // Grava a marca
    'marca': marca,
    // Grava o tipo em formato texto
    'tipo': tipo.valor,
    // Grava a forma em formato texto
    'forma': forma.valor,
    // Grava o preço
    'preco': preco,
    // Grava a URL da imagem tratada
    'imagem_url': temImagemUrl ? imagemUrl!.trim() : null,
    // Grava o estoque total
    'estoque': estoque,
    // Serializa cada linha da grade de tamanhos
    'tamanhos': tamanhos.map((t) => t.toJson()).toList(),
    // Grava o total de vendas dos 30 dias
    'vendas_30_dias': vendas30Dias,
  };

  /// Gera uma tabela padrão de medidas anatômicas (do tamanho 37 ao 45) com base na forma do calçado.
  static List<MedidaTamanho> gerarTabelaPadrao(FormaCalcado forma) {
    // Determina o comprimento inicial do tamanho 37 de acordo com a forma (estreita, padrão ou larga)
    final base37 = switch (forma) {
      // Forma estreita: 24,9 cm no 37
      FormaCalcado.estreita => 24.9,
      // Forma padrão: 25,0 cm no 37
      FormaCalcado.padrao => 25.0,
      // Forma larga: 25,2 cm no 37
      FormaCalcado.larga => 25.2,
    };
    // Devolve a grade do 37 ao 45 onde cada número aumenta ~0,667 cm (ponto francês padrão)
    return [
      // Percorre cada numeração inteira entre 37 e 45
      for (var n = 37; n <= 45; n++)
        // Instancia a medida individual correspondente à numeração
        MedidaTamanho(
          // Converte o número do tamanho para ponto flutuante
          numeracao: n.toDouble(),
          // Calcula o comprimento interno em centímetros arredondado para 1 casa decimal
          comprimentoCm: double.parse(
            (base37 + (n - 37) * 0.667).toStringAsFixed(1),
          ),
        ),
    ];
  }
}
