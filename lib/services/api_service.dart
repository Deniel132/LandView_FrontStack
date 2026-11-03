import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/calcado.dart';
import '../models/dashboard.dart';
import '../models/recomendacao.dart';
import '../models/saida_estoque.dart';
import '../models/usuario.dart';
import '../models/venda.dart';
import '../utils/criptografia_senha.dart';
import '../utils/formato.dart';
import 'api_exception.dart';
import 'dados_demo.dart';
import 'sessao.dart';

// Quem importa o ApiService também enxerga o ApiException.
export 'api_exception.dart';

/// Única porta de saída do app para a rede. Nenhuma tela monta URL
/// ou lê JSON por conta própria: tudo passa por aqui.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const _timeout = Duration(seconds: 35);

  /// Conectado à API real do Render por padrão (`DEMO=false`).
  /// Para rodar com dados fictícios locais: `--dart-define=DEMO=true`.
  static const bool _modoDemoEnv = bool.fromEnvironment(
    'DEMO',
    defaultValue: false,
  );
  static bool? modoDemoOverride;
  static bool get modoDemo => modoDemoOverride ?? _modoDemoEnv;

  /// URL publicada no Render (sem /docs no final).
  /// Para usar outra instância sem mexer no código:
  ///   flutter run --dart-define=API_URL=http://localhost:8000
  static String get baseUrl {
    const doAmbiente = String.fromEnvironment('API_URL');
    if (doAmbiente.isNotEmpty) {
      return doAmbiente.replaceAll(RegExp(r'/docs/?$'), '');
    }
    return 'https://landview-api.onrender.com';
  }

  // Conexão complementar com o Supabase da própria LandView_API para listagem
  // e metadados que a API do Render não expõe em rota de coleção.
  static const String _supabaseRestUrl =
      'https://pyqtqqlhizqmmnseaqgn.supabase.co/rest/v1';
  static const String _supabaseKey =
      'sb_publishable_3oalSxOHTWmQvWn9O0K96g_LLILAoKx';

  Map<String, String> get _supabaseHeaders => {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
    'apikey': _supabaseKey,
    'Authorization': 'Bearer $_supabaseKey',
    'Prefer': 'return=representation',
  };

  /// O token de sessão é enviado em requisições protegidas como Bearer.
  Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
    if (Sessao.instance.token != null)
      'Authorization': 'Bearer ${Sessao.instance.token}',
  };

  static const String _localApiUrl = 'http://127.0.0.1:8000';

  Uri _uri(String caminho) => Uri.parse('$baseUrl$caminho');
  Uri _localUri(String caminho) => Uri.parse('$_localApiUrl$caminho');
  Uri _sbUri(String caminho) => Uri.parse('$_supabaseRestUrl$caminho');

  // --------------------------------------------------------------- Login

  /// Faz login criptografando a senha no frontend (`enc:v1:...`), autentica em
  /// `POST /api/user/login` e valida a sessão em `GET /api/user/private`.
  Future<Usuario> login(String email, String senha) async {
    if (modoDemo) {
      final usuario = await DadosDemo.instance.login(email);
      Sessao.instance.iniciar('token-demo', usuario);
      return usuario;
    }

    final emailLimpo = email.trim();
    final senhaCriptografada = CriptografiaSenha.criptografar(senha);
    final dynamic json;
    try {
      json = await _enviar(
        (uri) => http.post(
          uri('/api/user/login'),
          headers: _headers,
          body: jsonEncode({
            'email': emailLimpo,
            'password': senhaCriptografada,
          }),
        ),
        autenticado: false, // 401 aqui é "senha errada", não "sessão expirada"
      );
    } on ApiException catch (e) {
      if (e.status == 401) {
        throw ApiException('E-mail ou senha incorretos.', status: 401);
      }
      if (e.status != null && e.status != 500) rethrow;
      return _loginSupabaseFallback(emailLimpo, senhaCriptografada);
    }

    final token = _ler(() {
      final t = json is String
          ? json
          : (json as Map<String, dynamic>)['access_token'] as String?;
      if (t == null || t.trim().isEmpty) {
        throw const FormatException('A API devolveu um token vazio.');
      }
      return t;
    });

    int? userId;
    String? userRole;
    try {
      final buscaUser = await http
          .get(
            _sbUri(
              '/user?select=id,email,role,active&email=eq.$emailLimpo&limit=1',
            ),
            headers: _supabaseHeaders,
          )
          .timeout(const Duration(seconds: 6));
      final lista = jsonDecode(utf8.decode(buscaUser.bodyBytes)) as List;
      if (lista.isNotEmpty) {
        final row = lista.first as Map<String, dynamic>;
        userId = (row['id'] as num?)?.toInt();
        userRole = row['role'] as String?;
      }
    } catch (_) {}

    final usuario = Usuario(
      id: userId,
      nome: emailLimpo.split('@').first,
      email: emailLimpo,
      perfil: userRole ?? 'SELLER',
    );
    Sessao.instance.iniciar(token, usuario);
    return usuario;
  }

  /// Valida o hash bcrypt real no banco compartilhado com o Render recebendo
  /// somente a senha criptografada (`enc:v1:...`). Se a senha estiver errada,
  /// recusa o login com erro 401.
  Future<Usuario> _loginSupabaseFallback(
    String email,
    String senhaCriptografada,
  ) async {
    final res = await http
        .post(
          _sbUri('/rpc/verificar_login'),
          headers: _supabaseHeaders,
          body: jsonEncode({
            'p_email': email,
            'p_password': senhaCriptografada,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('E-mail ou senha incorretos.', status: 401);
    }

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    final lista = decoded is List ? decoded : const [];
    if (lista.isEmpty) {
      throw ApiException('E-mail ou senha incorretos.', status: 401);
    }

    final row = lista.first as Map<String, dynamic>;
    final token = (row['token'] as String?)?.isNotEmpty == true
        ? row['token'] as String
        : 'sb-token-${row['id']}';
    final usuario = Usuario(
      id: (row['id'] as num?)?.toInt(),
      nome: email.split('@').first,
      email: email,
      perfil: row['role'] as String? ?? 'SELLER',
    );
    Sessao.instance.iniciar(token, usuario);

    return usuario;
  }

  /// Cria uma conta enviando a senha criptografada (`enc:v1:...`) e salvando
  /// com perfil (SELLER, OWNER ou USER) na API do Render ou no banco.
  Future<void> criarConta(
    String email,
    String senha, {
    String role = 'SELLER',
  }) async {
    if (modoDemo) {
      await DadosDemo.instance.criarConta(email, senha, role: role);
      return;
    }

    final emailLimpo = email.trim();
    final senhaCriptografada = CriptografiaSenha.criptografar(senha);
    final perfilFinal = role.trim().toUpperCase();

    // 1. Tenta a rota oficial pública POST /api/user/ da API no Render
    try {
      final res = await _enviar(
        (uri) => http.post(
          uri('/api/user/'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({
            'email': emailLimpo,
            'password': senhaCriptografada,
            'role': perfilFinal,
          }),
        ),
        autenticado: false,
      );
      if (res is Map<String, dynamic> && res['email'] != null) {
        return;
      }
    } on ApiException catch (e) {
      if (e.status == 409 || e.mensagem.toLowerCase().contains('ja existente')) {
        throw ApiException(
          'Já existe uma conta cadastrada com este e-mail.',
          status: 409,
        );
      }
      if (e.status == 400 && e.mensagem.contains('Email informado ja existente')) {
        throw ApiException(
          'Já existe uma conta cadastrada com este e-mail.',
          status: 409,
        );
      }
    } catch (_) {}

    // 2. Fallback via RPC Supabase
    final res = await http
        .post(
          _sbUri('/rpc/criar_usuario_hash'),
          headers: _supabaseHeaders,
          body: jsonEncode({
            'p_email': emailLimpo,
            'p_password': senhaCriptografada,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        await http
            .patch(
              _sbUri('/user?email=eq.$emailLimpo'),
              headers: _supabaseHeaders,
              body: jsonEncode({'role': perfilFinal}),
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
      return;
    }

    throw ApiException(
      'Não foi possível criar a conta. Este e-mail já está cadastrado.',
      status: 400,
    );
  }

  // ---------------------------------------------------------- Dashboard

  Future<Dashboard> dashboard() async {
    if (modoDemo) return DadosDemo.instance.dashboard();
    return _dashboardIntegrado();
  }

  // ---------------------------------------------------------------- CRUD

  Future<List<Calcado>> listar() async {
    if (modoDemo) return DadosDemo.instance.listar();
    return _listarIntegrado();
  }

  /// Consulta o produto em `GET /product/{id}` no Render e combina com
  /// categoria (`GET /category/{id}`) e estoque (`GET /stock/{id}`).
  Future<Calcado> buscar(int id) async {
    if (modoDemo) return DadosDemo.instance.buscar(id);

    // 1. Consulta GET /product/{id} na API do Render
    Map<String, dynamic>? produtoRender;
    try {
      final res = await _enviar(
        (uri) => http.get(uri('/product/$id'), headers: _headers),
      );
      if (res is Map<String, dynamic>) {
        produtoRender = res;
      }
    } on ApiException catch (e) {
      if (e.status == 401) rethrow;
    }

    final item = await _buscarSupabase(id);

    // 2. Se existir registro de estoque, também valida GET /stock/{stock_id} no Render
    final stockRow = await _obterStockRowSupabase(id);
    int estoqueAtual = item.estoque;
    if (stockRow != null) {
      final stockId = (stockRow['id'] as num).toInt();
      try {
        final stockRender = await _enviar(
          (uri) => http.get(uri('/stock/$stockId'), headers: _headers),
        );
        if (stockRender is Map<String, dynamic> &&
            stockRender['quantity'] != null) {
          estoqueAtual = (stockRender['quantity'] as num).toInt();
        }
      } catch (_) {}
    }

    if (produtoRender != null) {
      return Calcado(
        id: (produtoRender['product_id'] as num?)?.toInt() ?? item.id,
        nome: (produtoRender['product_name'] as String?) ?? item.nome,
        marca: item.marca,
        tipo: item.tipo,
        forma: item.forma,
        preco: (produtoRender['unit_value'] as num?)?.toDouble() ?? item.preco,
        imagemUrl: item.imagemUrl,
        imagemBytes: item.imagemBytes,
        estoque: estoqueAtual,
        tamanhos: item.tamanhos,
      );
    }

    return item.copyWith(estoque: estoqueAtual);
  }

  /// Converte a foto selecionada para persistência junto ao calçado.
  Future<String> enviarImagem(Uint8List bytes, String nomeArquivo) async {
    if (modoDemo) {
      throw ApiException(
        'O envio de fotos não está disponível no modo demonstração.',
      );
    }
    final lower = nomeArquivo.toLowerCase();
    final mime = (lower.endsWith('.jpg') || lower.endsWith('.jpeg'))
        ? 'image/jpeg'
        : lower.endsWith('.webp')
        ? 'image/webp'
        : 'image/png';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  /// Cria categoria (`POST /category/`), produto (`POST /product/`) e estoque
  /// (`POST /stock/`) integrados à API do Render e ao banco.
  Future<Calcado> criar(Calcado calcado) async {
    if (modoDemo) return DadosDemo.instance.criar(calcado);
    return _criarIntegrado(calcado);
  }

  /// Atualiza categoria (`PUT /category/{id}`), produto (`PUT /product/{id}`)
  /// e estoque (`PUT /stock/{id}`) na API do Render e no banco.
  Future<Calcado> atualizar(Calcado calcado) async {
    if (modoDemo) return DadosDemo.instance.atualizar(calcado);
    return _atualizarIntegrado(calcado);
  }

  /// Remove estoque (`DELETE /stock/{id}`) e produto (`DELETE /product/{id}`)
  /// usando as rotas da API do Render.
  Future<void> excluir(int id) async {
    if (modoDemo) return DadosDemo.instance.excluir(id);
    await _excluirIntegrado(id);
  }

  /// Registra a venda baixando o estoque diretamente na rota `PUT /stock/{id}`
  /// da API do Render.
  Future<VendaRegistrada> registrarVenda({
    required int calcadoId,
    required int quantidade,
  }) async {
    if (modoDemo) {
      return DadosDemo.instance.registrarVenda(
        calcadoId: calcadoId,
        quantidade: quantidade,
      );
    }
    return _registrarVendaIntegrada(
      calcadoId: calcadoId,
      quantidade: quantidade,
    );
  }

  /// Consulta o histórico de saídas de estoque (`GET /stock-exit/`).
  Future<List<SaidaEstoque>> listarSaidas({
    int page = 1,
    int pageSize = 15,
    int? idProduct,
    int? idStock,
  }) async {
    if (modoDemo) {
      return DadosDemo.instance.listarSaidas(
        page: page,
        pageSize: pageSize,
        idProduct: idProduct,
      );
    }

    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
      if (idProduct != null) 'id_product': idProduct.toString(),
      if (idStock != null) 'id_stock': idStock.toString(),
    };
    final queryString = Uri(queryParameters: queryParams).query;

    List<dynamic>? listaJson;
    // 1. Tenta a rota oficial GET /stock-exit/ da API
    try {
      final res = await _enviar(
        (uri) => http.get(uri('/stock-exit/?$queryString'), headers: _headers),
      );
      if (res is List) listaJson = res;
    } catch (_) {}

    // 2. Fallback direto no banco Supabase
    if (listaJson == null) {
      final start = (page - 1) * pageSize;
      final end = start + pageSize - 1;
      var sbPath = '/stock_exit_register?select=*&order=id.desc';
      if (idProduct != null) sbPath += '&id_product=eq.$idProduct';
      if (idStock != null) sbPath += '&id_stock=eq.$idStock';

      try {
        final resSb = await http
            .get(
              _sbUri(sbPath),
              headers: {
                ..._supabaseHeaders,
                'Range': '$start-$end',
              },
            )
            .timeout(_timeout);
        if (resSb.statusCode >= 200 && resSb.statusCode < 300) {
          final decoded = jsonDecode(utf8.decode(resSb.bodyBytes));
          if (decoded is List) listaJson = decoded;
        }
      } catch (_) {}
    }

    if (listaJson == null || listaJson.isEmpty) return const [];

    final saidas = listaJson
        .map((e) => SaidaEstoque.fromJson(e as Map<String, dynamic>))
        .toList();

    // Vincula com o nome do produto no catálogo
    try {
      final prods = await listar();
      final mapaNomes = {for (final p in prods) if (p.id != null) p.id!: p.nome};
      return [
        for (final s in saidas)
          s.copyWith(nomeProduto: mapaNomes[s.idProduto]),
      ];
    } catch (_) {
      return saidas;
    }
  }

  // -------------------------------------------------------- Recomendação

  Future<Recomendacao> recomendar({
    required int calcadoId,
    required double medidaPeCm,
    double? numeracaoHabitual,
    String? marcaHabitual,
  }) async {
    if (modoDemo) {
      return DadosDemo.instance.recomendar(
        calcadoId: calcadoId,
        medidaPeCm: medidaPeCm,
        numeracaoHabitual: numeracaoHabitual,
        marcaHabitual: marcaHabitual,
      );
    }
    return _recomendarIntegrado(
      calcadoId: calcadoId,
      medidaPeCm: medidaPeCm,
      numeracaoHabitual: numeracaoHabitual,
      marcaHabitual: marcaHabitual,
    );
  }

  // ------------------------------ Integração com LandView_API (Render)

  static List<Map<String, dynamic>> _tabelaPadrao(double comp37) => [
    for (var n = 37; n <= 45; n++)
      {
        'numeracao': n.toDouble(),
        'comprimento_cm': double.parse(
          (comp37 + (n - 37) * 0.667).toStringAsFixed(1),
        ),
      },
  ];

  Map<String, dynamic> _lerMeta(String? subCharacteristics) {
    if (subCharacteristics == null || subCharacteristics.trim().isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(subCharacteristics);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  (Calcado, int) _montarCalcado(
    Map<String, dynamic> prod,
    Map<int, Map<String, dynamic>> categoriasPorId,
    Map<int, Map<String, dynamic>> estoquesPorProdutoId,
  ) {
    final prodId = (prod['id'] as num).toInt();
    final catId = (prod['product_category_id'] as num?)?.toInt();
    final cat = catId != null ? categoriasPorId[catId] : null;
    final stock = estoquesPorProdutoId[prodId];

    final marca = (cat?['category_name'] as String?)?.trim().isNotEmpty == true
        ? cat!['category_name'] as String
        : 'LandView';
    final rawTipo = (cat?['category_type'] as String?)?.trim().toLowerCase();
    final tipo = rawTipo == 'chuteira' ? 'chuteira' : 'tenis';

    final rawForma = (stock?['characteristics'] as String?)
        ?.trim()
        .toLowerCase();
    final forma =
        (rawForma == 'estreita' || rawForma == 'padrao' || rawForma == 'larga')
        ? rawForma!
        : 'padrao';

    final meta = _lerMeta(stock?['sub_characteristics'] as String?);
    final rawTamanhos = meta['tamanhos'];
    final comp37Padrao = switch (forma) {
      'estreita' => 24.9,
      'larga' => 25.2,
      _ => 25.0,
    };
    final tamanhos = (rawTamanhos is List && rawTamanhos.isNotEmpty)
        ? rawTamanhos
        : _tabelaPadrao(comp37Padrao);

    final vendas = (meta['vendas_30_dias'] as num?)?.toInt() ?? 0;
    final estoque = (stock?['quantity'] as num?)?.toInt() ?? 0;

    final calcado = Calcado.fromJson({
      'id': prodId,
      'nome': prod['product_name'] as String,
      'marca': marca,
      'tipo': tipo,
      'forma': forma,
      'preco': (prod['unit_value'] as num).toDouble(),
      'estoque': estoque,
      'imagem_url': meta['imagem_url'] as String?,
      'tamanhos': tamanhos,
    });
    return (calcado, vendas);
  }

  Future<List<(Calcado, int)>> _carregarTodosComVendas() async {
    final respostas = await Future.wait([
      http
          .get(
            _sbUri('/product?select=*&active=eq.true&order=id.asc'),
            headers: _supabaseHeaders,
          )
          .timeout(_timeout),
      http
          .get(_sbUri('/product_category?select=*'), headers: _supabaseHeaders)
          .timeout(_timeout),
      http
          .get(
            _sbUri('/stock_product?select=*&order=id.asc'),
            headers: _supabaseHeaders,
          )
          .timeout(_timeout),
    ]);

    final produtos =
        jsonDecode(utf8.decode(respostas[0].bodyBytes)) as List<dynamic>;
    final categorias =
        jsonDecode(utf8.decode(respostas[1].bodyBytes)) as List<dynamic>;
    final estoques =
        jsonDecode(utf8.decode(respostas[2].bodyBytes)) as List<dynamic>;

    final categoriasPorId = <int, Map<String, dynamic>>{
      for (final c in categorias)
        ((c as Map<String, dynamic>)['id'] as num).toInt(): c,
    };
    final estoquesPorProdutoId = <int, Map<String, dynamic>>{};
    for (final s in estoques) {
      final mapa = s as Map<String, dynamic>;
      final pid = (mapa['id_product'] as num).toInt();
      estoquesPorProdutoId.putIfAbsent(pid, () => mapa);
    }

    return [
      for (final p in produtos)
        _montarCalcado(
          p as Map<String, dynamic>,
          categoriasPorId,
          estoquesPorProdutoId,
        ),
    ];
  }

  Future<List<Calcado>> _listarIntegrado() async {
    final pares = await _carregarTodosComVendas();
    return [for (final (c, _) in pares) c];
  }

  Future<Calcado> _buscarSupabase(int id) async {
    final pares = await _carregarTodosComVendas();
    for (final (c, _) in pares) {
      if (c.id == id) return c;
    }
    throw ApiException('Calçado não encontrado.', status: 404);
  }

  Future<Map<String, dynamic>?> _obterStockRowSupabase(int productId) async {
    final stockRes = await http
        .get(
          _sbUri(
            '/stock_product?select=*&id_product=eq.$productId&order=id.asc',
          ),
          headers: _supabaseHeaders,
        )
        .timeout(_timeout);
    final stockLista = jsonDecode(utf8.decode(stockRes.bodyBytes)) as List;
    if (stockLista.isEmpty) return null;
    return stockLista.first as Map<String, dynamic>;
  }

  Future<int> _obterOuCriarCategoriaId(String marca, String tipo) async {
    final m = Uri.encodeQueryComponent(marca.trim());
    final t = Uri.encodeQueryComponent(tipo.trim());
    final busca = await http
        .get(
          _sbUri(
            '/product_category?select=*&category_name=eq.$m&category_type=eq.$t&limit=1',
          ),
          headers: _supabaseHeaders,
        )
        .timeout(_timeout);
    final encontrados = jsonDecode(utf8.decode(busca.bodyBytes)) as List;
    if (encontrados.isNotEmpty) {
      final catId =
          ((encontrados.first as Map<String, dynamic>)['id'] as num).toInt();
      // Valida GET /category/{id} na API do Render
      try {
        await _enviar(
          (uri) => http.get(uri('/category/$catId'), headers: _headers),
        );
      } catch (_) {}
      return catId;
    }

    // Cria a categoria pela rota POST /category/ da API no Render
    try {
      final criadoRender = await _enviar(
        (uri) => http.post(
          uri('/category/'),
          headers: _headers,
          body: jsonEncode({
            'category_name': marca.trim(),
            'category_type': tipo.trim(),
          }),
        ),
      );
      if (criadoRender is Map<String, dynamic> &&
          criadoRender['category_id'] != null) {
        return (criadoRender['category_id'] as num).toInt();
      }
    } on ApiException catch (e) {
      if (e.status == 401) rethrow;
    }

    final criacao = await http
        .post(
          _sbUri('/product_category'),
          headers: _supabaseHeaders,
          body: jsonEncode({
            'category_name': marca.trim(),
            'category_type': tipo.trim(),
          }),
        )
        .timeout(_timeout);
    final criados = jsonDecode(utf8.decode(criacao.bodyBytes)) as List;
    return ((criados.first as Map<String, dynamic>)['id'] as num).toInt();
  }

  Future<Calcado> _criarIntegrado(Calcado c) async {
    final catId = await _obterOuCriarCategoriaId(c.marca, c.tipo.valor);

    int? prodId;
    // Tenta criar pela rota POST /product/ do Render
    try {
      final prodRender = await _enviar(
        (uri) => http.post(
          uri('/product/'),
          headers: _headers,
          body: jsonEncode({
            'product_name': c.nome,
            'unit_value': c.preco,
            'product_category_id': catId,
          }),
        ),
      );
      if (prodRender is Map<String, dynamic> &&
          prodRender['product_id'] != null) {
        prodId = (prodRender['product_id'] as num).toInt();
      }
    } on ApiException catch (e) {
      if (e.status == 401) rethrow;
    }

    if (prodId == null) {
      final prodRes = await http
          .post(
            _sbUri('/product'),
            headers: _supabaseHeaders,
            body: jsonEncode({
              'product_name': c.nome,
              'unit_value': c.preco,
              'product_category_id': catId,
              'active': true,
            }),
          )
          .timeout(_timeout);
      final prodLista = jsonDecode(utf8.decode(prodRes.bodyBytes)) as List;
      prodId =
          ((prodLista.first as Map<String, dynamic>)['id'] as num).toInt();
    }

    // Cria o estoque pela rota POST /stock/ do Render
    int? stockId;
    try {
      final stockRender = await _enviar(
        (uri) => http.post(
          uri('/stock/'),
          headers: _headers,
          body: jsonEncode({'product_id': prodId, 'quantity': c.estoque}),
        ),
      );
      if (stockRender is Map<String, dynamic> &&
          stockRender['stock_id'] != null) {
        stockId = (stockRender['stock_id'] as num).toInt();
      }
    } on ApiException catch (e) {
      if (e.status == 401) rethrow;
    }

    final meta = {
      'imagem_url': c.temImagemUrl ? c.imagemUrl!.trim() : null,
      'tamanhos': c.tamanhos.map((t) => t.toJson()).toList(),
      'vendas_30_dias': 0,
    };

    if (stockId != null) {
      await http
          .patch(
            _sbUri('/stock_product?id=eq.$stockId'),
            headers: _supabaseHeaders,
            body: jsonEncode({
              'characteristics': c.forma.valor,
              'sub_characteristics': jsonEncode(meta),
            }),
          )
          .timeout(_timeout);
    } else {
      await http
          .post(
            _sbUri('/stock_product'),
            headers: _supabaseHeaders,
            body: jsonEncode({
              'id_product': prodId,
              'quantity': c.estoque,
              'characteristics': c.forma.valor,
              'sub_characteristics': jsonEncode(meta),
            }),
          )
          .timeout(_timeout);
    }

    return buscar(prodId);
  }

  Future<Calcado> _atualizarIntegrado(Calcado c) async {
    final id = c.id!;
    final catId = await _obterOuCriarCategoriaId(c.marca, c.tipo.valor);

    // Tenta atualizar via PUT /product/{id} no Render e garante no banco
    try {
      await _enviar(
        (uri) => http.put(
          uri('/product/$id'),
          headers: _headers,
          body: jsonEncode({
            'product_name': c.nome,
            'unit_value': c.preco,
            'product_category_id': catId,
          }),
        ),
      );
    } on ApiException catch (e) {
      if (e.status == 401) rethrow;
    }

    await http
        .patch(
          _sbUri('/product?id=eq.$id'),
          headers: _supabaseHeaders,
          body: jsonEncode({
            'product_name': c.nome,
            'unit_value': c.preco,
            'product_category_id': catId,
            'active': true,
          }),
        )
        .timeout(_timeout);

    final stockRow = await _obterStockRowSupabase(id);
    var vendasAtuais = 0;
    if (stockRow != null) {
      final oldMeta = _lerMeta(stockRow['sub_characteristics'] as String?);
      vendasAtuais = (oldMeta['vendas_30_dias'] as num?)?.toInt() ?? 0;
    }

    final meta = {
      'imagem_url': c.temImagemUrl ? c.imagemUrl!.trim() : null,
      'tamanhos': c.tamanhos.map((t) => t.toJson()).toList(),
      'vendas_30_dias': vendasAtuais,
    };

    if (stockRow != null) {
      final stockId = (stockRow['id'] as num).toInt();
      // Atualiza a quantidade usando PUT /stock/{stock_id} na API do Render
      try {
        await _enviar(
          (uri) => http.put(
            uri('/stock/$stockId'),
            headers: _headers,
            body: jsonEncode({'product_id': id, 'quantity': c.estoque}),
          ),
        );
      } on ApiException catch (e) {
        if (e.status == 401) rethrow;
      }

      await http
          .patch(
            _sbUri('/stock_product?id=eq.$stockId'),
            headers: _supabaseHeaders,
            body: jsonEncode({
              'quantity': c.estoque,
              'characteristics': c.forma.valor,
              'sub_characteristics': jsonEncode(meta),
            }),
          )
          .timeout(_timeout);
    } else {
      await http
          .post(
            _sbUri('/stock_product'),
            headers: _supabaseHeaders,
            body: jsonEncode({
              'id_product': id,
              'quantity': c.estoque,
              'characteristics': c.forma.valor,
              'sub_characteristics': jsonEncode(meta),
            }),
          )
          .timeout(_timeout);
    }

    return buscar(id);
  }

  Future<void> _excluirIntegrado(int id) async {
    final stockRow = await _obterStockRowSupabase(id);
    if (stockRow != null) {
      final stockId = (stockRow['id'] as num).toInt();
      // Deleta o estoque via DELETE /stock/{stock_id} no Render
      try {
        await _enviar(
          (uri) => http.delete(uri('/stock/$stockId'), headers: _headers),
        );
      } on ApiException catch (e) {
        if (e.status == 401) rethrow;
      }
    }

    // Garante limpeza de registros de estoque vinculados ao produto
    await http
        .delete(
          _sbUri('/stock_product?id_product=eq.$id'),
          headers: _supabaseHeaders,
        )
        .timeout(_timeout);

    // Deleta o produto via DELETE /product/{product_id} no Render
    try {
      await _enviar((uri) => http.delete(uri('/product/$id'), headers: _headers));
    } on ApiException catch (e) {
      if (e.status == 401) rethrow;
      await http
          .delete(_sbUri('/product?id=eq.$id'), headers: _supabaseHeaders)
          .timeout(_timeout);
    }
  }

  Future<VendaRegistrada> _registrarVendaIntegrada({
    required int calcadoId,
    required int quantidade,
  }) async {
    if (quantidade <= 0) {
      throw ApiException('A quantidade da venda deve ser maior que zero.');
    }
    final stockRow = await _obterStockRowSupabase(calcadoId);
    if (stockRow == null) {
      throw ApiException('Estoque não encontrado para este calçado.');
    }

    final stockId = (stockRow['id'] as num).toInt();
    var estoqueAtual = (stockRow['quantity'] as num?)?.toInt() ?? 0;

    // Confere o estoque atual diretamente em GET /stock/{stock_id} no Render
    try {
      final stockRender = await _enviar(
        (uri) => http.get(uri('/stock/$stockId'), headers: _headers),
      );
      if (stockRender is Map<String, dynamic> &&
          stockRender['quantity'] != null) {
        estoqueAtual = (stockRender['quantity'] as num).toInt();
      }
    } on ApiException catch (e) {
      if (e.status == 401) rethrow;
    }

    if (quantidade > estoqueAtual) {
      throw ApiException(
        'Estoque insuficiente. Disponível: $estoqueAtual unidade(s).',
      );
    }

    final novoEstoque = estoqueAtual - quantidade;

    // Faz a baixa do estoque chamando PUT /stock/{stock_id} na API do Render
    try {
      await _enviar(
        (uri) => http.put(
          uri('/stock/$stockId'),
          headers: _headers,
          body: jsonEncode({
            'product_id': calcadoId,
            'quantity': novoEstoque,
          }),
        ),
      );
    } on ApiException catch (e) {
      if (e.status == 401) rethrow;
    }

    final meta = _lerMeta(stockRow['sub_characteristics'] as String?);
    meta['vendas_30_dias'] =
        ((meta['vendas_30_dias'] as num?)?.toInt() ?? 0) + quantidade;

    await http
        .patch(
          _sbUri('/stock_product?id=eq.$stockId'),
          headers: _supabaseHeaders,
          body: jsonEncode({
            'quantity': novoEstoque,
            'sub_characteristics': jsonEncode(meta),
          }),
        )
        .timeout(_timeout);

    // Registra a saída no histórico de auditoria (tabela stock_exit_register)
    try {
      final currentUserId = Sessao.instance.usuario?.id ?? 22;
      await http
          .post(
            _sbUri('/stock_exit_register'),
            headers: _supabaseHeaders,
            body: jsonEncode({
              'id_product': calcadoId,
              'id_user': currentUserId,
              'id_stock': stockId,
              'quantity': quantidade,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}

    return VendaRegistrada(
      id: DateTime.now().millisecondsSinceEpoch % 1000000,
      calcadoId: calcadoId,
      quantidade: quantidade,
      estoqueAtual: novoEstoque,
      dataVenda: DateTime.now(),
    );
  }

  Future<Dashboard> _dashboardIntegrado() async {
    const limiteBaixo = 5;
    const limiteAlto = 40;
    final pares = await _carregarTodosComVendas();

    ItemDashboard toItem((Calcado, int) par) => ItemDashboard(
      id: par.$1.id!,
      nome: par.$1.nome,
      marca: par.$1.marca,
      vendas: par.$2,
      estoque: par.$1.estoque,
    );

    final vendidos = [...pares]..sort((a, b) => b.$2.compareTo(a.$2));
    final baixo = pares.where((p) => p.$1.estoque <= limiteBaixo).toList()
      ..sort((a, b) => a.$1.estoque.compareTo(b.$1.estoque));
    final alto = pares.where((p) => p.$1.estoque >= limiteAlto).toList()
      ..sort((a, b) => b.$1.estoque.compareTo(a.$1.estoque));

    // Consulta a rota oficial GET /dashboard/ do Render
    ExtremoEstoque? menorEstoque;
    ExtremoEstoque? maiorEstoque;
    try {
      final resDash = await _enviar(
        (uri) => http.get(uri('/dashboard/'), headers: _headers),
      );
      if (resDash is Map<String, dynamic>) {
        menorEstoque = ExtremoEstoque.talvez(resDash['lowest_stock']);
        maiorEstoque = ExtremoEstoque.talvez(resDash['highest_stock']);
      }
    } catch (_) {}

    return Dashboard(
      resumo: ResumoDashboard(
        totalModelos: pares.length,
        unidadesEmEstoque: pares.fold(0, (s, p) => s + p.$1.estoque),
        vendas30Dias: pares.fold(0, (s, p) => s + p.$2),
        modelosAcabando: baixo.length,
        modelosComExcesso: alto.length,
        limiteEstoqueBaixo: limiteBaixo,
        limiteEstoqueAlto: limiteAlto,
      ),
      maisVendidos: vendidos.where((p) => p.$2 > 0).take(5).map(toItem).toList(),
      estoqueBaixo: baixo.map(toItem).toList(),
      estoqueAlto: alto.map(toItem).toList(),
      menorEstoque: menorEstoque,
      maiorEstoque: maiorEstoque,
    );
  }

  Future<Recomendacao> _recomendarIntegrado({
    required int calcadoId,
    required double medidaPeCm,
    double? numeracaoHabitual,
    String? marcaHabitual,
  }) async {
    final c = await buscar(calcadoId);
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
  }

  // ------------------------------------------------------------ Internos

  /// Executa a chamada no Render; se o navegador bloquear por CORS (quando a
  /// porta 8000 já está ocupada pelo uvicorn local), tenta automaticamente a
  /// API local em http://127.0.0.1:8000.
  Future<dynamic> _enviar(
    Future<http.Response> Function(Uri Function(String) uri) chamada, {
    bool autenticado = true,
  }) async {
    try {
      final resposta = await chamada(_uri).timeout(_timeout);
      return _tratar(resposta, autenticado);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      try {
        final respLocal = await chamada(_localUri).timeout(
          const Duration(seconds: 8),
        );
        return _tratar(respLocal, autenticado);
      } on ApiException {
        rethrow;
      } catch (_) {}
      throw ApiException(
        'A API demorou demais para responder. Confira se o servidor está ligado em $baseUrl.',
      );
    } catch (_) {
      try {
        final respLocal = await chamada(_localUri).timeout(
          const Duration(seconds: 8),
        );
        return _tratar(respLocal, autenticado);
      } on ApiException {
        rethrow;
      } catch (_) {}
      throw ApiException(
        'Não foi possível conectar à API em $baseUrl. Confira o servidor e a rede.',
      );
    }
  }

  dynamic _tratar(http.Response resposta, bool autenticado) {
    final texto = utf8.decode(resposta.bodyBytes);
    dynamic json;
    if (texto.isNotEmpty) {
      try {
        json = jsonDecode(texto);
      } catch (_) {
        json = null;
      }
    }

    if (resposta.statusCode >= 200 && resposta.statusCode < 300) return json;

    // Token recusado em uma rota protegida: encerra a sessão e o app
    // volta sozinho para a tela de login.
    if (resposta.statusCode == 401 && autenticado) {
      Sessao.instance.expirar();
      throw ApiException('Sua sessão expirou. Entre novamente.', status: 401);
    }

    throw ApiException(
      _mensagemDeErro(resposta.statusCode, json),
      status: resposta.statusCode,
    );
  }

  /// Lê o campo `detail` do FastAPI (texto simples ou lista do Pydantic).
  String _mensagemDeErro(int status, dynamic json) {
    if (json is Map && json['detail'] != null) {
      final detalhe = json['detail'];
      if (detalhe is String) return detalhe;
      if (detalhe is List && detalhe.isNotEmpty) {
        return detalhe
            .map((e) {
              if (e is Map) {
                final campo = (e['loc'] as List?)
                    ?.where((p) => p != 'body')
                    .join('.');
                final msg = e['msg'];
                return (campo == null || campo.isEmpty)
                    ? '$msg'
                    : '$campo: $msg';
              }
              return '$e';
            })
            .join('\n');
      }
    }
    switch (status) {
      case 401:
        return 'E-mail ou senha incorretos.';
      case 404:
        return 'Registro não encontrado.';
      case 422:
        return 'Os dados enviados são inválidos.';
      default:
        return status >= 500
            ? 'Erro interno no servidor (código $status).'
            : 'A API recusou a requisição (código $status).';
    }
  }

  /// Protege contra resposta fora do contrato (campo faltando, tipo errado).
  T _ler<T>(T Function() converter) {
    try {
      return converter();
    } catch (_) {
      throw ApiException(
        'A API respondeu em um formato inesperado. Confira o contrato dos endpoints.',
      );
    }
  }
}
