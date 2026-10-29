import '../models/calcado.dart';
import '../models/dashboard.dart';
import '../models/recomendacao.dart';
import '../models/usuario.dart';
import '../models/venda.dart';
import 'api_exception.dart';

/// Substitui a API quando o app roda com:
///   flutter run --dart-define=DEMO=true
///
/// Serve só para ver e apresentar as telas sem o backend pronto. Tudo vive
/// em memória e some ao fechar o app. As medidas, preços, estoques e vendas
/// abaixo são INVENTADOS para a demonstração e não representam a loja.
class DadosDemo {
  DadosDemo._();
  static final DadosDemo instance = DadosDemo._();

  static const _latencia = Duration(milliseconds: 350);
  static const limiteBaixo = 5;
  static const limiteAlto = 40;

  final Map<int, int> _vendas = {}; // id -> vendas em 30 dias
  late final List<Calcado> _lista = _semear();
  int _proximoId = 100;
  int _proximaVendaId = 1;

  /// Pequena espera para os indicadores de carregamento aparecerem.
  Future<T> _atraso<T>(T Function() acao) async {
    await Future<void>.delayed(_latencia);
    return acao();
  }

  // ---------------------------------------------------------------- dados

  /// Tabela de 37 a 45. O comprimento interno cresce ~0,667 cm por número
  /// (um "ponto francês"); `comp37` é o comprimento interno do número 37.
  static List<MedidaTamanho> _tabela(double comp37) => [
    for (var n = 37; n <= 45; n++)
      MedidaTamanho(
        numeracao: n.toDouble(),
        comprimentoCm: double.parse(
          (comp37 + (n - 37) * 0.667).toStringAsFixed(1),
        ),
      ),
  ];

  List<Calcado> _semear() {
    Calcado c(
      int id,
      String nome,
      String marca,
      TipoCalcado tipo,
      FormaCalcado forma,
      double preco,
      int estoque,
      int vendas,
      double comp37,
    ) {
      _vendas[id] = vendas;
      return Calcado(
        id: id,
        nome: nome,
        marca: marca,
        tipo: tipo,
        forma: forma,
        preco: preco,
        estoque: estoque,
        tamanhos: _tabela(comp37),
      );
    }

    const t = TipoCalcado.tenis, ch = TipoCalcado.chuteira;
    const e = FormaCalcado.estreita,
        p = FormaCalcado.padrao,
        l = FormaCalcado.larga;

    return [
      c(1, 'Mercurial Vapor 15 Academy', 'Nike', ch, e, 429.90, 6, 14, 24.9),
      c(2, 'Predator Accuracy.4', 'Adidas', ch, p, 349.90, 22, 11, 25.0),
      c(3, 'Air Zoom Pegasus 40', 'Nike', t, p, 799.90, 4, 19, 25.0),
      c(4, 'Gel-Nimbus 25', 'Asics', t, l, 1299.90, 48, 3, 25.2),
      c(5, 'Wave Rider 27', 'Mizuno', t, p, 899.90, 2, 16, 24.9),
      c(6, 'Ultraboost Light', 'Adidas', t, p, 999.90, 55, 5, 25.1),
      c(7, 'Future 7 Play', 'Puma', ch, l, 299.90, 18, 9, 24.8),
      c(8, 'Vomero 17', 'Nike', t, p, 1099.90, 31, 8, 25.0),
    ];
  }

  // ------------------------------------------------------------- operações

  Future<Usuario> login(String email) => _atraso(() {
    final primeiroNome = email
        .trim()
        .split('@')
        .first
        .split(RegExp(r'[._-]'))
        .first;
    final nome = primeiroNome.isEmpty
        ? 'Cliente'
        : '${primeiroNome[0].toUpperCase()}${primeiroNome.substring(1)}';
    return Usuario(id: 1, nome: nome, email: email);
  });

  Future<List<Calcado>> listar() => _atraso(() => List.of(_lista));

  Future<Calcado> buscar(int id) => _atraso(() => _achar(id));

  Future<Calcado> criar(Calcado c) => _atraso(() {
    final novo = Calcado(
      id: _proximoId++,
      nome: c.nome,
      marca: c.marca,
      tipo: c.tipo,
      forma: c.forma,
      preco: c.preco,
      imagemUrl: c.imagemUrl,
      imagemBytes: c.imagemBytes,
      estoque: c.estoque,
      tamanhos: c.tamanhos,
    );
    _vendas[novo.id!] = 0;
    _lista.add(novo);
    return novo;
  });

  Future<Calcado> atualizar(Calcado c) => _atraso(() {
    final i = _lista.indexWhere((x) => x.id == c.id);
    if (i < 0) throw ApiException('Calçado não encontrado.', status: 404);
    _lista[i] = c;
    return c;
  });

  Future<void> excluir(int id) => _atraso(() {
    _achar(id);
    _lista.removeWhere((x) => x.id == id);
    _vendas.remove(id);
  });

  Future<VendaRegistrada> registrarVenda({
    required int calcadoId,
    required int quantidade,
  }) => _atraso(() {
    if (quantidade <= 0) {
      throw ApiException('A quantidade da venda deve ser maior que zero.');
    }
    final calcado = _achar(calcadoId);
    if (quantidade > calcado.estoque) {
      throw ApiException(
        'Estoque insuficiente. Disponível: ${calcado.estoque} unidade(s).',
      );
    }

    final indice = _lista.indexWhere((c) => c.id == calcadoId);
    final atualizado = calcado.copyWith(estoque: calcado.estoque - quantidade);
    _lista[indice] = atualizado;
    _vendas[calcadoId] = (_vendas[calcadoId] ?? 0) + quantidade;

    return VendaRegistrada(
      id: _proximaVendaId++,
      calcadoId: calcadoId,
      quantidade: quantidade,
      estoqueAtual: atualizado.estoque,
      dataVenda: DateTime.now(),
    );
  });

  Calcado _achar(int id) => _lista.firstWhere(
    (c) => c.id == id,
    orElse: () => throw ApiException('Calçado não encontrado.', status: 404),
  );

  Future<Dashboard> dashboard() => _atraso(() {
    ItemDashboard item(Calcado c) => ItemDashboard(
      id: c.id!,
      nome: c.nome,
      marca: c.marca,
      vendas: _vendas[c.id] ?? 0,
      estoque: c.estoque,
    );

    final vendidos = [..._lista]
      ..sort((a, b) => (_vendas[b.id] ?? 0).compareTo(_vendas[a.id] ?? 0));
    final baixo = _lista.where((c) => c.estoque <= limiteBaixo).toList()
      ..sort((a, b) => a.estoque.compareTo(b.estoque));
    final alto = _lista.where((c) => c.estoque >= limiteAlto).toList()
      ..sort((a, b) => b.estoque.compareTo(a.estoque));

    return Dashboard(
      resumo: ResumoDashboard(
        totalModelos: _lista.length,
        unidadesEmEstoque: _lista.fold(0, (s, c) => s + c.estoque),
        vendas30Dias: _vendas.values.fold(0, (s, v) => s + v),
        modelosAcabando: baixo.length,
        modelosComExcesso: alto.length,
        limiteEstoqueBaixo: limiteBaixo,
        limiteEstoqueAlto: limiteAlto,
      ),
      maisVendidos: vendidos
          .where((c) => (_vendas[c.id] ?? 0) > 0)
          .take(5)
          .map(item)
          .toList(),
      estoqueBaixo: baixo.map(item).toList(),
      estoqueAlto: alto.map(item).toList(),
    );
  });

  /// Versão simplificada da regra do backend (folga por tipo + ajuste por
  /// forma). No uso real, o cálculo é feito pelo algoritmo em Python.
  Future<Recomendacao> recomendar({
    required int calcadoId,
    required double medidaPeCm,
  }) => _atraso(() {
    final c = _achar(calcadoId);
    final folga = c.tipo == TipoCalcado.chuteira ? 0.6 : 1.0;
    final ajuste = switch (c.forma) {
      FormaCalcado.estreita => 0.3,
      FormaCalcado.padrao => 0.0,
      FormaCalcado.larga => -0.2,
    };
    final alvo = medidaPeCm + folga + ajuste;

    final t = c.tamanhos;
    var i = t.indexWhere((m) => m.comprimentoCm >= alvo - 1e-9);
    if (i < 0) i = t.length - 1;

    return Recomendacao(
      tamanho: t[i].numeracao,
      alternativa: i + 1 < t.length ? t[i + 1].numeracao : null,
      folgaCm: double.parse(
        (t[i].comprimentoCm - medidaPeCm).toStringAsFixed(1),
      ),
      observacao:
          'Cálculo de demonstração. No uso real, este resultado vem do algoritmo em Python.',
    );
  });
}
