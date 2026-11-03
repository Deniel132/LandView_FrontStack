import '../models/calcado.dart';
import '../models/dashboard.dart';
import '../models/recomendacao.dart';
import '../models/saida_estoque.dart';
import '../models/usuario.dart';
import '../models/venda.dart';
import '../utils/formato.dart';
import 'api_exception.dart';

/// Substitui a API quando o app roda com:
///   flutter run --dart-define=DEMO=true
///
/// Serve para demonstrar e testar todas as telas sem o backend Python. Tudo
/// vive em memória e é reiniciado ao fechar o app.
class DadosDemo {
  DadosDemo._();
  static final DadosDemo instance = DadosDemo._();

  static const _latencia = Duration(milliseconds: 280);
  static const limiteBaixo = 5;
  static const limiteAlto = 40;

  final Map<int, int> _vendas = {}; // id -> vendas em 30 dias
  final Set<String> _contasCadastradas = {'cliente@loja.com'};
  final List<SaidaEstoque> _saidas = [];
  late List<Calcado> _lista = _semear();
  int _proximoId = 100;
  int _proximaVendaId = 1;

  /// Reinicia os dados em memória (útil para testes automatizados).
  void resetar() {
    _vendas.clear();
    _saidas.clear();
    _contasCadastradas
      ..clear()
      ..add('cliente@loja.com');
    _lista = _semear();
    _proximoId = 100;
    _proximaVendaId = 1;
  }

  /// Pequena espera para os indicadores de carregamento aparecerem.
  Future<T> _atraso<T>(T Function() acao) async {
    await Future<void>.delayed(_latencia);
    return acao();
  }

  // ---------------------------------------------------------------- dados

  /// Gera uma tabela padrão de 37 a 45 para a [forma] informada.
  static List<MedidaTamanho> gerarTabelaPadrao(FormaCalcado forma) {
    final base37 = switch (forma) {
      FormaCalcado.estreita => 24.9,
      FormaCalcado.padrao => 25.0,
      FormaCalcado.larga => 25.2,
    };
    return _tabela(base37);
  }

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
    final partes = email
        .trim()
        .split('@')
        .first
        .split(RegExp(r'[._-]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final nome = partes.isEmpty
        ? 'Vendedor'
        : partes
              .map((p) => '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}')
              .join(' ');
    return Usuario(
      id: 1,
      nome: nome,
      email: email.trim(),
      perfil: 'SELLER',
    );
  });

  Future<void> criarConta(
    String email,
    String senha, {
    String role = 'SELLER',
  }) => _atraso(() {
    final normalizado = email.trim().toLowerCase();
    if (_contasCadastradas.contains(normalizado)) {
      throw ApiException(
        'Já existe uma conta cadastrada com este e-mail.',
        status: 409,
      );
    }
    _contasCadastradas.add(normalizado);
  });

  Future<List<Calcado>> listar() => _atraso(() => List.of(_lista));

  Future<Calcado> buscar(int id) => _atraso(() => _achar(id));

  Future<Calcado> criar(Calcado c) => _atraso(() {
    final novo = c.copyWith(id: _proximoId++);
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

    final vendaId = _proximaVendaId++;
    _saidas.insert(
      0,
      SaidaEstoque(
        id: vendaId,
        idProduto: calcadoId,
        idUsuario: 1,
        idEstoque: calcadoId,
        quantidade: quantidade,
        nomeProduto: calcado.nome,
        emailUsuario: 'vendedor@loja.com',
      ),
    );

    return VendaRegistrada(
      id: vendaId,
      calcadoId: calcadoId,
      quantidade: quantidade,
      estoqueAtual: atualizado.estoque,
      dataVenda: DateTime.now(),
    );
  });

  Future<List<SaidaEstoque>> listarSaidas({
    int page = 1,
    int pageSize = 15,
    int? idProduct,
    int? idStock,
  }) => _atraso(() {
    var filtradas = _saidas;
    if (idProduct != null) {
      filtradas = filtradas.where((s) => s.idProduto == idProduct).toList();
    }
    if (idStock != null) {
      filtradas = filtradas.where((s) => s.idEstoque == idStock).toList();
    }
    final start = (page - 1) * pageSize;
    if (start >= filtradas.length) return <SaidaEstoque>[];
    return filtradas.skip(start).take(pageSize).toList();
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

    final ordenadosPorEstoque = [..._lista]
      ..sort((a, b) => a.estoque.compareTo(b.estoque));
    final menor = ordenadosPorEstoque.isNotEmpty ? ordenadosPorEstoque.first : null;
    final maior = ordenadosPorEstoque.isNotEmpty ? ordenadosPorEstoque.last : null;

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
      menorEstoque: menor != null
          ? ExtremoEstoque(
              produtoId: menor.id!,
              nome: menor.nome,
              preco: menor.preco,
              quantidade: menor.estoque,
            )
          : null,
      maiorEstoque: maior != null
          ? ExtremoEstoque(
              produtoId: maior.id!,
              nome: maior.nome,
              preco: maior.preco,
              quantidade: maior.estoque,
            )
          : null,
    );
  });

  /// Regra de recomendação local (folga por tipo + ajuste por forma + análise
  /// de numeração habitual). No uso conectado, o cálculo vem da API Python.
  Future<Recomendacao> recomendar({
    required int calcadoId,
    required double medidaPeCm,
    double? numeracaoHabitual,
    String? marcaHabitual,
  }) => _atraso(() {
    final c = _achar(calcadoId);
    if (c.tamanhos.isEmpty) {
      throw ApiException(
        'Este calçado não possui tabela de medidas cadastrada.',
        status: 400,
      );
    }

    final folgaBase = c.tipo == TipoCalcado.chuteira ? 0.6 : 1.0;
    final ajusteForma = switch (c.forma) {
      FormaCalcado.estreita => 0.3,
      FormaCalcado.padrao => 0.0,
      FormaCalcado.larga => -0.2,
    };
    final alvo = medidaPeCm + folgaBase + ajusteForma;

    final t = c.tamanhos;
    var i = t.indexWhere((m) => m.comprimentoCm >= alvo - 1e-9);
    final acimaDaTabela = i < 0;
    if (acimaDaTabela) i = t.length - 1;

    final escolhido = t[i];
    final folgaReal = double.parse(
      (escolhido.comprimentoCm - medidaPeCm).toStringAsFixed(1),
    );

    final notas = <String>[
      if (acimaDaTabela)
        'A medida informada fica no limite superior da grade cadastrada.'
      else
        'Palmilha interna de ${Formato.cm(escolhido.comprimentoCm)} '
            '(folga de ${Formato.cm(folgaReal)} para forma ${c.forma.rotulo.toLowerCase()}).',
    ];

    if (numeracaoHabitual != null) {
      final dif = escolhido.numeracao - numeracaoHabitual;
      final refMarca = (marcaHabitual != null && marcaHabitual.isNotEmpty)
          ? ' ($marcaHabitual)'
          : '';
      if (dif.abs() >= 0.5) {
        notas.add(
          dif > 0
              ? 'Sugerimos numeração acima da habitual ${Formato.numeracao(numeracaoHabitual)}$refMarca para preservar o conforto.'
              : 'Este modelo possui forma mais ampla que a habitual ${Formato.numeracao(numeracaoHabitual)}$refMarca.',
        );
      } else {
        notas.add(
          'Compatível com a numeração habitual ${Formato.numeracao(numeracaoHabitual)}$refMarca do cliente.',
        );
      }
    }

    return Recomendacao(
      tamanho: escolhido.numeracao,
      alternativa: i + 1 < t.length ? t[i + 1].numeracao : null,
      folgaCm: folgaReal,
      observacao: notas.join(' '),
    );
  });
}
