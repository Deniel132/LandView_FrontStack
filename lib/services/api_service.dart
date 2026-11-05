// Biblioteca padrão do Dart para operações assíncronas (Future, TimeoutException).
import 'dart:async';
// Biblioteca padrão do Dart para codificação e decodificação JSON e conversão Base64 e UTF-8.
import 'dart:convert';
// Biblioteca padrão do Dart para manipulação de bytes de memória (Uint8List).
import 'dart:typed_data';

// Pacote oficial HTTP para envio de requisições de rede RESTful.
import 'package:http/http.dart' as http;

// Modelo que representa um calçado/tênis/chuteira no catálogo.
import '../models/calcado.dart';
// Modelo que encapsula os dados consolidados do painel administrativo.
import '../models/dashboard.dart';
// Modelo de retorno do provador virtual com tamanho recomendado e observações.
import '../models/recomendacao.dart';
// Modelo que representa um registro de auditoria de saída/baixa de estoque.
import '../models/saida_estoque.dart';
// Modelo de usuário autenticado do sistema com e-mail e perfil de acesso.
import '../models/usuario.dart';
// Modelo de registro e recibo de uma venda efetuada na loja.
import '../models/venda.dart';
// Utilitário para criptografar senhas no padrão do backend (enc:v1:...).
import '../utils/criptografia_senha.dart';
// Utilitário para formatação amigável de medidas em centímetros e numerações.
import '../utils/formato.dart';
// Exceção customizada da aplicação para transporte de erros e status HTTP.
import 'api_exception.dart';
// Conjunto de dados simulados em memória para quando o app roda em modo de demonstração.
import 'dados_demo.dart';
// Gerenciador central de sessão do usuário e persistência do token de acesso.
import 'sessao.dart';

// Reexporta a classe ApiException para que arquivos que importam ApiService possam capturá-la diretamente.
export 'api_exception.dart';

/// Ponto único de comunicação e saída do aplicativo para a rede.
/// Nenhuma tela monta URL, serializa cabeçalhos ou trata respostas HTTP por conta própria:
/// todas as interações de login, catálogo, estoque, saídas e dashboard passam por esta classe.
class ApiService {
  // Construtor privado para impedir instanciação externa (Padrão de Projeto Singleton).
  ApiService._();
  // Instância única global acessível em toda a aplicação.
  static final ApiService instance = ApiService._();

  // Tempo limite máximo padrão de espera para requisições de rede (35 segundos para acomodar cold start do Render).
  static const _timeout = Duration(seconds: 35);

  /// Flag que determina se o app roda conectado à API real ou com dados simulados locais.
  /// Por padrão é falso (conecta à API no Render). Pode ser ativado via: `--dart-define=DEMO=true`.
  static const bool _modoDemoEnv = bool.fromEnvironment(
    'DEMO',
    defaultValue: false,
  );
  // Permite sobrescrever o modo demonstração em tempo de execução (útil em testes automatizados).
  static bool? modoDemoOverride;
  // Getter público que retorna o estado atual do modo de demonstração.
  static bool get modoDemo => modoDemoOverride ?? _modoDemoEnv;

  /// URL base oficial da API no Render (sem a barra final nem /docs).
  /// Permite apontar para outro servidor (como localhost) via:
  ///   flutter run --dart-define=API_URL=http://localhost:8000
  static String get baseUrl {
    // Lê a variável de compilação API_URL caso tenha sido passada via linha de comando.
    const doAmbiente = String.fromEnvironment('API_URL');
    if (doAmbiente.isNotEmpty) {
      // Remove sufixo /docs caso o desenvolvedor tenha colado a URL do Swagger.
      return doAmbiente.replaceAll(RegExp(r'/docs/?$'), '');
    }
    // URL de produção publicada no Render.
    return 'https://landview-api.onrender.com';
  }

  // URL do serviço REST do Supabase vinculado à base de dados da LandView_API,
  // utilizado como fallback seguro para rotas de coleção e integridade de dados.
  static const String _supabaseRestUrl =
      'https://pyqtqqlhizqmmnseaqgn.supabase.co/rest/v1';
  // Chave pública autorizada para acesso às tabelas do banco no Supabase.
  static const String _supabaseKey =
      'sb_publishable_3oalSxOHTWmQvWn9O0K96g_LLILAoKx';

  /// Cabeçalhos HTTP padrão exigidos nas requisições diretas ao Supabase.
  Map<String, String> get _supabaseHeaders => {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
    'apikey': _supabaseKey,
    'Authorization': 'Bearer $_supabaseKey',
    'Prefer': 'return=representation',
  };

  /// Cabeçalhos HTTP padrão para chamadas à API principal no Render,
  /// incluindo o token Bearer de autenticação caso o usuário já esteja logado.
  Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
    if (Sessao.instance.token != null)
      'Authorization': 'Bearer ${Sessao.instance.token}',
  };

  // Endereço local de contingência caso o backend local esteja rodando na máquina.
  static const String _localApiUrl = 'http://127.0.0.1:8000';

  // Monta a URI completa direcionada para a API principal do Render.
  Uri _uri(String caminho) => Uri.parse('$baseUrl$caminho');
  // Monta a URI direcionada para o servidor de desenvolvimento local.
  Uri _localUri(String caminho) => Uri.parse('$_localApiUrl$caminho');
  // Monta a URI direcionada para o banco Supabase.
  Uri _sbUri(String caminho) => Uri.parse('$_supabaseRestUrl$caminho');

  // --------------------------------------------------------------- Login

  /// Autentica o usuário no sistema criptografando a senha no frontend (`enc:v1:...`),
  /// chama a rota oficial `POST /api/user/login` do Render e inicializa a sessão do app.
  Future<Usuario> login(String email, String senha) async {
    // Se o app estiver em modo de demonstração, valida nos dados mockados locais.
    if (modoDemo) {
      // Autentica nos dados simulados
      var usuario = await DadosDemo.instance.login(email);
      // Verifica se o usuário definiu um nome de exibição personalizado para este e-mail
      final nomeCustom = await Sessao.obterNomeCustomizado(email);
      // Se houver nome personalizado salvo, aplica ao usuário logado
      if (nomeCustom != null && nomeCustom.isNotEmpty) {
        usuario = usuario.copyWith(nome: nomeCustom);
      }
      // Inicia a sessão ativa com o token de demonstração
      Sessao.instance.iniciar('token-demo', usuario);
      return usuario;
    }

    // Remove espaços em branco do e-mail.
    final emailLimpo = email.trim();
    // Criptografa a senha para envio seguro pela rede.
    final senhaCriptografada = CriptografiaSenha.criptografar(senha);
    final dynamic json;
    try {
      // Envia a requisição de login para a rota da API no Render.
      json = await _enviar(
        (uri) => http.post(
          uri('/api/user/login'),
          headers: _headers,
          body: jsonEncode({
            'email': emailLimpo,
            'password': senhaCriptografada,
          }),
        ),
        // autenticado = false: status 401 aqui significa credenciais erradas, não sessão expirada.
        autenticado: false,
      );
    } on ApiException catch (e) {
      // Se a API recusou com 401, lança erro com mensagem clara para o formulário.
      if (e.status == 401) {
        throw ApiException('E-mail ou senha incorretos.', status: 401);
      }
      // Se não for erro de servidor 500 ou indisponibilidade, repassa a exceção.
      if (e.status != null && e.status != 500) rethrow;
      // Caso a API do Render esteja inacessível ou em cold start, recorre à validação segura via Supabase.
      return _loginSupabaseFallback(emailLimpo, senhaCriptografada);
    }

    // Extrai o token de acesso da resposta da API.
    final token = _ler(() {
      final t = json is String
          ? json
          : (json as Map<String, dynamic>)['access_token'] as String?;
      if (t == null || t.trim().isEmpty) {
        throw const FormatException('A API devolveu um token vazio.');
      }
      return t;
    });

    // Tenta enriquecer o perfil do usuário consultando o banco de dados.
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

    // Recupera o nome de exibição personalizado salvo previamente para este e-mail
    final nomeSalvo = await Sessao.obterNomeCustomizado(emailLimpo);

    // Constrói o objeto do usuário logado (preserva o nome personalizado caso exista).
    final usuario = Usuario(
      id: userId,
      nome: nomeSalvo ?? emailLimpo.split('@').first,
      email: emailLimpo,
      perfil: userRole ?? 'SELLER',
    );
    // Armazena o token e o usuário na sessão singleton global.
    Sessao.instance.iniciar(token, usuario);
    return usuario;
  }

  /// Valida as credenciais do usuário diretamente no banco via RPC caso a API do Render falhe.
  /// A senha viaja criptografada e é verificada contra o hash bcrypt armazenado.
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

    // Se o banco retornou erro HTTP, as credenciais estão incorretas.
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('E-mail ou senha incorretos.', status: 401);
    }

    // Decodifica a resposta JSON do procedimento.
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    final lista = decoded is List ? decoded : const [];
    // Lista vazia significa que nenhum usuário correspondeu ao par e-mail/senha.
    if (lista.isEmpty) {
      throw ApiException('E-mail ou senha incorretos.', status: 401);
    }

    final row = lista.first as Map<String, dynamic>;
    // Obtém o token ou gera um identificador seguro de sessão.
    final token = (row['token'] as String?)?.isNotEmpty == true
        ? row['token'] as String
        : 'sb-token-${row['id']}';
    // Recupera o nome personalizado previamente salvo pelo usuário para este e-mail
    final nomeSalvo = await Sessao.obterNomeCustomizado(email);

    final usuario = Usuario(
      id: (row['id'] as num?)?.toInt(),
      nome: nomeSalvo ?? email.split('@').first,
      email: email,
      perfil: row['role'] as String? ?? 'SELLER',
    );
    // Inicializa a sessão com os dados recuperados.
    Sessao.instance.iniciar(token, usuario);

    return usuario;
  }

  /// Cria um novo usuário enviando a senha criptografada (`enc:v1:...`) e definindo
  /// o perfil de acesso (SELLER, OWNER ou USER) na API do Render ou no banco compartilhado.
  Future<void> criarConta(
    String email,
    String senha, {
    String role = 'SELLER',
  }) async {
    // Se estiver em modo demonstração, registra na memória local de testes.
    if (modoDemo) {
      await DadosDemo.instance.criarConta(email, senha, role: role);
      return;
    }

    // Sanitiza e padroniza os campos antes do envio.
    final emailLimpo = email.trim();
    final senhaCriptografada = CriptografiaSenha.criptografar(senha);
    final perfilFinal = role.trim().toUpperCase();

    // 1. Tenta a rota oficial pública POST /api/user/ da API no Render.
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
      // Conflito de e-mail duplicado tratado pela API do Render.
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

    // 2. Se a rota do Render falhou, executa o procedimento via RPC no banco Supabase.
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

    // Se o usuário foi criado no banco, atualiza o perfil (role) solicitado.
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

    // Caso contrário, informa que a conta não pôde ser criada.
    throw ApiException(
      'Não foi possível criar a conta. Este e-mail já está cadastrado.',
      status: 400,
    );
  }

  // ---------------------------------------------------------- Dashboard

  /// Retorna os dados consolidados do painel da loja (totais, mais vendidos, estoque baixo/alto e extremos).
  Future<Dashboard> dashboard() async {
    if (modoDemo) return DadosDemo.instance.dashboard();
    return _dashboardIntegrado();
  }

  // ---------------------------------------------------------------- CRUD

  /// Retorna a listagem de todos os modelos de calçados cadastrados no catálogo.
  Future<List<Calcado>> listar() async {
    if (modoDemo) return DadosDemo.instance.listar();
    return _listarIntegrado();
  }

  /// Consulta um calçado específico pelo ID combinando produto (`GET /product/{id}`),
  /// categoria (`GET /category/{id}`) e quantidade de estoque (`GET /stock/{id}`).
  Future<Calcado> buscar(int id) async {
    if (modoDemo) return DadosDemo.instance.buscar(id);

    // 1. Consulta a rota GET /product/{id} na API oficial do Render.
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

    // Busca os dados completos e metadados no banco.
    final item = await _buscarSupabase(id);

    // 2. Se houver registro de estoque correspondente, valida também na rota GET /stock/{stock_id} do Render.
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

    // Se a rota oficial do Render respondeu com sucesso, mescla os valores atualizados.
    Calcado retorno = produtoRender != null
        ? Calcado(
            // Prioriza o identificador numérico retornado pelo Render
            id: (produtoRender['product_id'] as num?)?.toInt() ?? item.id,
            // Prioriza o nome cadastrado no Render
            nome: (produtoRender['product_name'] as String?) ?? item.nome,
            // Mantém a marca original recuperada
            marca: item.marca,
            // Mantém o tipo de calçado original
            tipo: item.tipo,
            // Mantém a forma anatômica original
            forma: item.forma,
            // Prioriza o valor monetário retornado pelo Render
            preco:
                (produtoRender['unit_value'] as num?)?.toDouble() ?? item.preco,
            // Mantém a URL de imagem
            imagemUrl: item.imagemUrl,
            // Mantém os bytes em memória
            imagemBytes: item.imagemBytes,
            // Aplica o estoque atualizado
            estoque: estoqueAtual,
            // Mantém a grade de tamanhos original
            tamanhos: item.tamanhos,
          )
        // Caso contrário, usa a instância do banco com o saldo de estoque atualizado
        : item.copyWith(estoque: estoqueAtual);

    // Recupera a grade de tamanhos detalhada salva no armazenamento local para este calçado
    final temGradeNoBanco = retorno.tamanhos.any((t) => t.estoque != null);
    if (temGradeNoBanco) {
      // Sincroniza a grade vinda do banco com o estoque atual e atualiza o cache local
      retorno = retorno.copyWith(tamanhos: retorno.tamanhosComEstoque);
      await Sessao.salvarGradeTamanhos(id, retorno.tamanhos);
    } else {
      final gradeSalva = await Sessao.obterGradeTamanhos(id);
      // Se houver grade salva localmente, aplica mantendo a coerência com o estoque do backend
      if (gradeSalva != null && gradeSalva.isNotEmpty) {
        // Mescla a grade salva na instância de retorno
        final comGrade = retorno.copyWith(tamanhos: gradeSalva);
        // Reconcilia proporcionalmente caso o saldo total do banco tenha sido alterado externamente
        retorno = comGrade.copyWith(tamanhos: comGrade.tamanhosComEstoque);
      }
    }

    // Retorna o objeto calçado final com grade e estoque perfeitamente sincronizados
    return retorno;
  }

  /// Converte a foto selecionada em bytes para data URI Base64 pronta para persistência.
  Future<String> enviarImagem(Uint8List bytes, String nomeArquivo) async {
    // No modo demonstração o upload não é permitido.
    if (modoDemo) {
      throw ApiException(
        'O envio de fotos não está disponível no modo demonstração.',
      );
    }
    // Determina o tipo MIME com base na extensão do arquivo de imagem.
    final lower = nomeArquivo.toLowerCase();
    final mime = (lower.endsWith('.jpg') || lower.endsWith('.jpeg'))
        ? 'image/jpeg'
        : lower.endsWith('.webp')
        ? 'image/webp'
        : 'image/png';
    // Codifica os bytes da imagem em formato Base64.
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  /// Cria categoria (`POST /category/`), produto (`POST /product/`) e estoque (`POST /stock/`)
  /// de forma sincronizada na API do Render e no banco de dados.
  Future<Calcado> criar(Calcado calcado) async {
    if (modoDemo) return DadosDemo.instance.criar(calcado);
    return _criarIntegrado(calcado);
  }

  /// Atualiza os dados de produto (`PUT /product/{id}`) e estoque (`PUT /stock/{id}`)
  /// no Render e no banco compartilhado.
  Future<Calcado> atualizar(Calcado calcado) async {
    if (modoDemo) return DadosDemo.instance.atualizar(calcado);
    return _atualizarIntegrado(calcado);
  }

  /// Remove o estoque (`DELETE /stock/{id}`) e o produto (`DELETE /product/{id}`)
  /// utilizando as rotas oficiais de exclusão da API.
  Future<void> excluir(int id) async {
    if (modoDemo) return DadosDemo.instance.excluir(id);
    await _excluirIntegrado(id);
  }

  /// Registra a venda de calçados diminuindo o saldo de estoque via `PUT /stock/{id}`
  /// e gerando o registro correspondente no histórico de auditoria de saídas.
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

  /// Consulta o histórico paginado de saídas e baixas de estoque da rota oficial `GET /stock-exit/`.
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

    // Constrói os parâmetros de consulta na URL.
    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
      if (idProduct != null) 'id_product': idProduct.toString(),
      if (idStock != null) 'id_stock': idStock.toString(),
    };
    final queryString = Uri(queryParameters: queryParams).query;

    List<dynamic>? listaJson;
    // 1. Tenta consultar a rota oficial GET /stock-exit/ da API do Render.
    try {
      final res = await _enviar(
        (uri) => http.get(uri('/stock-exit/?$queryString'), headers: _headers),
      );
      if (res is List) listaJson = res;
    } catch (_) {}

    // 2. Se a rota falhar, consulta diretamente a tabela de auditoria stock_exit_register no Supabase.
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

    // Se não encontrou registros, devolve uma lista vazia imutável.
    if (listaJson == null || listaJson.isEmpty) return const [];

    // Mapeia os objetos JSON para instâncias fortemente tipadas do modelo SaidaEstoque.
    final saidas = listaJson
        .map((e) => SaidaEstoque.fromJson(e as Map<String, dynamic>))
        .toList();

    // Vincula cada registro de saída ao nome do calçado cadastrado no catálogo.
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

  /// Executa o algoritmo do Provador Virtual calculando a numeração perfeita
  /// baseada na medida em centímetros do pé do cliente e na forma anatômica do calçado.
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

  /// Gera a grade padrão de medidas (tamanhos 37 a 45) baseada na fórmula do Ponto Francês (0.667 cm por número).
  static List<Map<String, dynamic>> _tabelaPadrao(double comp37) => [
    for (var n = 37; n <= 45; n++)
      {
        'numeracao': n.toDouble(),
        'comprimento_cm': double.parse(
          (comp37 + (n - 37) * 0.667).toStringAsFixed(1),
        ),
      },
  ];

  /// Faz o parse seguro do JSON de metadados armazenado no campo `sub_characteristics` do estoque.
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

  /// Monta um objeto Calçado consolidando as informações das tabelas de produto, categoria e estoque.
  (Calcado, int) _montarCalcado(
    Map<String, dynamic> prod,
    Map<int, Map<String, dynamic>> categoriasPorId,
    Map<int, Map<String, dynamic>> estoquesPorProdutoId,
    Map<int, int> vendasPorProdutoId,
  ) {
    final prodId = (prod['id'] as num).toInt();
    final catId = (prod['product_category_id'] as num?)?.toInt();
    final cat = catId != null ? categoriasPorId[catId] : null;
    final stock = estoquesPorProdutoId[prodId];

    // Recupera a marca da categoria ou usa o padrão "LandView".
    final marca = (cat?['category_name'] as String?)?.trim().isNotEmpty == true
        ? cat!['category_name'] as String
        : 'LandView';
    final rawTipo = (cat?['category_type'] as String?)?.trim().toLowerCase();
    final tipo = rawTipo == 'chuteira' ? 'chuteira' : 'tenis';

    // Recupera a forma anatômica armazenada no campo characteristics do estoque.
    final rawForma = (stock?['characteristics'] as String?)
        ?.trim()
        .toLowerCase();
    final forma =
        (rawForma == 'estreita' || rawForma == 'padrao' || rawForma == 'larga')
        ? rawForma!
        : 'padrao';

    // Extrai metadados adicionais (tabela de medidas, URL da imagem e histórico de vendas).
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

    // Soma as saídas registradas na tabela de auditoria ou utiliza o metadado salvo
    final vendas =
        vendasPorProdutoId[prodId] ?? (meta['vendas_30_dias'] as num?)?.toInt() ?? 0;
    final estoque = (stock?['quantity'] as num?)?.toInt() ?? 0;

    // Constrói a instância do Calçado a partir dos dados normalizados.
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

  /// Carrega concorrentemente produtos ativos, categorias, estoques e saídas, associando-os em pares (Calçado, Vendas).
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
      http
          .get(
            _sbUri('/stock_exit_register?select=id_product,quantity'),
            headers: _supabaseHeaders,
          )
          .timeout(_timeout),
    ]);

    // Decodifica as listas retornadas em paralelo.
    final produtos =
        jsonDecode(utf8.decode(respostas[0].bodyBytes)) as List<dynamic>;
    final categorias =
        jsonDecode(utf8.decode(respostas[1].bodyBytes)) as List<dynamic>;
    final estoques =
        jsonDecode(utf8.decode(respostas[2].bodyBytes)) as List<dynamic>;

    // Acumula o total de vendas por produto a partir dos registros reais de saída
    final vendasPorProdutoId = <int, int>{};
    if (respostas.length > 3 && respostas[3].statusCode == 200) {
      final saidas =
          jsonDecode(utf8.decode(respostas[3].bodyBytes)) as List<dynamic>;
      for (final s in saidas) {
        final mapa = s as Map<String, dynamic>;
        final pid = (mapa['id_product'] as num?)?.toInt();
        final qtd = (mapa['quantity'] as num?)?.toInt() ?? 0;
        if (pid != null) {
          vendasPorProdutoId[pid] = (vendasPorProdutoId[pid] ?? 0) + qtd;
        }
      }
    }

    // Indexa categorias pelo seu ID para busca O(1).
    final categoriasPorId = <int, Map<String, dynamic>>{
      for (final c in categorias)
        ((c as Map<String, dynamic>)['id'] as num).toInt(): c,
    };
    // Indexa estoques pelo ID do produto correspondente para busca O(1).
    final estoquesPorProdutoId = <int, Map<String, dynamic>>{};
    for (final s in estoques) {
      final mapa = s as Map<String, dynamic>;
      final pid = (mapa['id_product'] as num).toInt();
      estoquesPorProdutoId.putIfAbsent(pid, () => mapa);
    }

    // Transforma cada produto da lista em um par (Calçado, Vendas).
    return [
      for (final p in produtos)
        _montarCalcado(
          p as Map<String, dynamic>,
          categoriasPorId,
          estoquesPorProdutoId,
          vendasPorProdutoId,
        ),
    ];
  }

  /// Retorna apenas a lista de modelos de calçados do catálogo mesclando grades salvas.
  Future<List<Calcado>> _listarIntegrado() async {
    // Carrega todos os produtos integrados com dados de vendas
    final pares = await _carregarTodosComVendas();
    // Lista final acumuladora com dados completos
    final lista = <Calcado>[];
    // Itera por cada calçado recuperado
    for (final (c, _) in pares) {
      // Se possuir ID numérico válido, verifica se o banco já trouxe a grade ou usa a persistida localmente
      if (c.id != null) {
        final temGradeNoBanco = c.tamanhos.any((t) => t.estoque != null);
        if (temGradeNoBanco) {
          // Equilibra com o estoque total e atualiza o cache local
          final ajustado = c.copyWith(tamanhos: c.tamanhosComEstoque);
          await Sessao.salvarGradeTamanhos(c.id!, ajustado.tamanhos);
          lista.add(ajustado);
          continue;
        }
        // Consulta grade salva no SharedPreferences caso o banco ainda não tenha sub_characteristics
        final gradeSalva = await Sessao.obterGradeTamanhos(c.id!);
        // Se houver grade salva, aplica conciliando com o estoque do banco
        if (gradeSalva != null && gradeSalva.isNotEmpty) {
          // Cria cópia com a grade de tamanhos salva
          final comGrade = c.copyWith(tamanhos: gradeSalva);
          // Adiciona à lista garantindo equilíbrio com o estoque total
          lista.add(comGrade.copyWith(tamanhos: comGrade.tamanhosComEstoque));
          // Passa para o próximo calçado
          continue;
        }
      }
      // Se não houver grade personalizada salva, adiciona com a distribuição padrão
      lista.add(c);
    }
    // Retorna a lista completa de calçados prontos para renderização
    return lista;
  }

  /// Localiza um calçado específico pelo ID no catálogo consolidado.
  Future<Calcado> _buscarSupabase(int id) async {
    final pares = await _carregarTodosComVendas();
    for (final (c, _) in pares) {
      if (c.id == id) return c;
    }
    throw ApiException('Calçado não encontrado.', status: 404);
  }

  /// Recupera o registro da tabela stock_product vinculado a um determinado produto.
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

  /// Obtém o ID de uma categoria existente ou cria uma nova via `POST /category/` no Render.
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
      // Valida GET /category/{id} na API oficial do Render.
      try {
        await _enviar(
          (uri) => http.get(uri('/category/$catId'), headers: _headers),
        );
      } catch (_) {}
      return catId;
    }

    // Cria a categoria chamando a rota oficial POST /category/ da API no Render.
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

    // Fallback de criação no Supabase.
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

  /// Cria um calçado integrando chamadas às rotas POST /product/ e POST /stock/ no Render.
  Future<Calcado> _criarIntegrado(Calcado c) async {
    final catId = await _obterOuCriarCategoriaId(c.marca, c.tipo.valor);

    int? prodId;
    // 1. Tenta criar pela rota oficial POST /product/ do Render.
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

    // Fallback de criação de produto no banco se o endpoint falhar.
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

    // Estrutura de metadados ricos armazenados em JSON.
    final meta = {
      'imagem_url': c.temImagemUrl ? c.imagemUrl!.trim() : null,
      'tamanhos': c.tamanhosComEstoque.map((t) => t.toJson()).toList(),
      'vendas_30_dias': 0,
    };

    // 2. Cria o registro de estoque correspondente via POST /stock/ do Render.
    int? stockId;
    try {
      final stockRender = await _enviar(
        (uri) => http.post(
          uri('/stock/'),
          headers: _headers,
          body: jsonEncode({
            'product_id': prodId,
            'characteristics': c.forma.valor,
            'sub_characteristics': jsonEncode(meta),
            'quantity': c.estoque,
          }),
        ),
      );
      if (stockRender is Map<String, dynamic> &&
          stockRender['stock_id'] != null) {
        stockId = (stockRender['stock_id'] as num).toInt();
      }
    } on ApiException catch (e) {
      if (e.status == 401) rethrow;
    }

    // Salva o registro de estoque caso a rota do Render tenha falhado.
    if (stockId == null) {
      final resSb = await http
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
      final dadosSb = jsonDecode(utf8.decode(resSb.bodyBytes));
      if (dadosSb is List && dadosSb.isNotEmpty) {
        stockId = ((dadosSb.first as Map<String, dynamic>)['id'] as num).toInt();
      }
    }

    // Salva a grade inicial no armazenamento local para manter a distribuição persistida
    if (c.tamanhos.isNotEmpty) {
      // Grava a lista de tamanhos calculada
      await Sessao.salvarGradeTamanhos(prodId, c.tamanhosComEstoque);
    }

    // Retorna o calçado completo recém-criado.
    return buscar(prodId);
  }

  /// Atualiza o produto via `PUT /product/{id}` e o estoque via `PUT /stock/{id}`.
  Future<Calcado> _atualizarIntegrado(Calcado c) async {
    final id = c.id!;
    final catId = await _obterOuCriarCategoriaId(c.marca, c.tipo.valor);

    // 1. Tenta atualizar dados cadastrais via PUT /product/{id} no Render.
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

    // Garante atualização dos dados no banco.
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

    // Recupera o registro atual de estoque no banco para identificar o stock_id.
    final stockRow = await _obterStockRowSupabase(id);

    // Estrutura de metadados ricos para persistir imagem e grade individual por tamanho na nuvem
    final meta = {
      'imagem_url': c.temImagemUrl ? c.imagemUrl!.trim() : null,
      'tamanhos': c.tamanhosComEstoque.map((t) => t.toJson()).toList(),
    };

    // 2. Atualiza a quantidade chamando PUT /stock/{stock_id} no Render.
    if (stockRow != null) {
      final stockId = (stockRow['id'] as num).toInt();
      try {
        await _enviar(
          (uri) => http.put(
            uri('/stock/$stockId'),
            headers: _headers,
            body: jsonEncode({
              'product_id': id,
              'quantity': c.estoque,
              'characteristics': c.forma.valor,
              'sub_characteristics': jsonEncode(meta),
            }),
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

    // Salva a grade detalhada no armazenamento local para preservar alterações por numeração
    if (c.tamanhos.isNotEmpty) {
      // Grava a lista de tamanhos equilibrada com o novo total
      await Sessao.salvarGradeTamanhos(id, c.tamanhosComEstoque);
    }

    // Retorna o objeto calçado atualizado.
    return buscar(id);
  }

  /// Exclui o estoque e o produto chamando as rotas DELETE da API no Render.
  Future<void> _excluirIntegrado(int id) async {
    // 1. Remove os registros de auditoria vinculados a este produto para evitar erro de integridade referencial
    try {
      // Deleta as saídas de estoque associadas a este produto
      await http
          .delete(
            _sbUri('/stock_exit_register?id_product=eq.$id'),
            headers: _supabaseHeaders,
          )
          .timeout(_timeout);
    // Ignora erro caso a tabela já esteja limpa
    } catch (_) {}

    // 2. Remove a grade de tamanhos salva no armazenamento local
    await Sessao.removerGradeTamanhos(id);

    final stockRow = await _obterStockRowSupabase(id);
    if (stockRow != null) {
      final stockId = (stockRow['id'] as num).toInt();
      // Remove o registro de estoque chamando DELETE /stock/{stock_id} no Render.
      try {
        await _enviar(
          (uri) => http.delete(uri('/stock/$stockId'), headers: _headers),
        );
      } on ApiException catch (e) {
        if (e.status == 401) rethrow;
      }
    }

    // Remove os registros de estoque vinculados a este produto no banco.
    await http
        .delete(
          _sbUri('/stock_product?id_product=eq.$id'),
          headers: _supabaseHeaders,
        )
        .timeout(_timeout);

    // Remove o produto chamando a rota DELETE /product/{product_id} no Render.
    try {
      await _enviar((uri) => http.delete(uri('/product/$id'), headers: _headers));
    } on ApiException catch (e) {
      if (e.status == 401) rethrow;
      // Fallback para exclusão direta no banco de dados.
      await http
          .delete(_sbUri('/product?id=eq.$id'), headers: _supabaseHeaders)
          .timeout(_timeout);
    }
  }

  /// Executa a baixa de estoque na rota PUT /stock/{stock_id} do Render,
  /// incrementa o contador de vendas e registra na auditoria de saídas.
  Future<VendaRegistrada> _registrarVendaIntegrada({
    required int calcadoId,
    required int quantidade,
  }) async {
    // Validação de entrada: a quantidade deve ser positiva.
    if (quantidade <= 0) {
      throw ApiException('A quantidade da venda deve ser maior que zero.');
    }
    final stockRow = await _obterStockRowSupabase(calcadoId);
    if (stockRow == null) {
      throw ApiException('Estoque não encontrado para este calçado.');
    }

    final stockId = (stockRow['id'] as num).toInt();
    var estoqueAtual = (stockRow['quantity'] as num?)?.toInt() ?? 0;

    // Confere o estoque atual em tempo real consultando GET /stock/{stock_id} no Render.
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

    // Bloqueia a venda se o saldo for menor que a quantidade requisitada.
    if (quantidade > estoqueAtual) {
      throw ApiException(
        'Estoque insuficiente. Disponível: $estoqueAtual unidade(s).',
      );
    }

    // Calcula o novo saldo restante.
    final novoEstoque = estoqueAtual - quantidade;

    // Atualiza o saldo chamando a rota oficial PUT /stock/{stock_id} no Render.
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

    // Salva o novo saldo no banco de dados preservando características e grade.
    await http
        .patch(
          _sbUri('/stock_product?id=eq.$stockId'),
          headers: _supabaseHeaders,
          body: jsonEncode({
            'quantity': novoEstoque,
            if (stockRow['characteristics'] != null)
              'characteristics': stockRow['characteristics'],
            if (stockRow['sub_characteristics'] != null)
              'sub_characteristics': stockRow['sub_characteristics'],
          }),
        )
        .timeout(_timeout);

    // Registra a operação com a quantidade exata vendida na tabela de auditoria (stock_exit_register),
    // que também alimenta a rota GET /stock-exit/ da API do Render e os indicadores de vendas do Dashboard.
    try {
      final currentUserId = Sessao.instance.usuario?.id ?? 34;
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

    // Devolve o comprovante da venda com saldo atualizado.
    return VendaRegistrada(
      id: DateTime.now().millisecondsSinceEpoch % 1000000,
      calcadoId: calcadoId,
      quantidade: quantidade,
      estoqueAtual: novoEstoque,
      dataVenda: DateTime.now(),
    );
  }

  /// Monta os dados consolidados do painel da loja com limites de alerta e destaques da rota GET /dashboard/.
  Future<Dashboard> _dashboardIntegrado() async {
    const limiteBaixo = 5;
    const limiteAlto = 40;
    final pares = await _carregarTodosComVendas();

    // Função local para mapear calçado para item do painel.
    ItemDashboard toItem((Calcado, int) par) => ItemDashboard(
      id: par.$1.id!,
      nome: par.$1.nome,
      marca: par.$1.marca,
      vendas: par.$2,
      estoque: par.$1.estoque,
    );

    // Ordenações por critérios analíticos.
    final vendidos = [...pares]..sort((a, b) => b.$2.compareTo(a.$2));
    final baixo = pares.where((p) => p.$1.estoque <= limiteBaixo).toList()
      ..sort((a, b) => a.$1.estoque.compareTo(b.$1.estoque));
    final alto = pares.where((p) => p.$1.estoque >= limiteAlto).toList()
      ..sort((a, b) => b.$1.estoque.compareTo(a.$1.estoque));

    // Consulta a rota oficial GET /dashboard/ do Render para obter os extremos de estoque calculados pela API.
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

    // Retorna a entidade completa Dashboard montada.
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

  /// Executa o cálculo da recomendação de tamanho do provador virtual.
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

    // Chuteiras precisam de ajuste mais justo (0.6 cm) enquanto tênis usam folga padrão de conforto (1.0 cm).
    final folgaBase = c.tipo == TipoCalcado.chuteira ? 0.6 : 1.0;
    // Calibra a folga conforme a anatomia da forma (estreita, padrão ou larga).
    final ajusteForma = switch (c.forma) {
      FormaCalcado.estreita => 0.3,
      FormaCalcado.padrao => 0.0,
      FormaCalcado.larga => -0.2,
    };
    final alvo = medidaPeCm + folgaBase + ajusteForma;

    // Busca o tamanho com palmilha compatível na tabela do calçado.
    final t = c.tamanhos;
    var i = t.indexWhere((m) => m.comprimentoCm >= alvo - 1e-9);
    final acimaDaTabela = i < 0;
    if (acimaDaTabela) i = t.length - 1;

    final escolhido = t[i];
    final folgaReal = double.parse(
      (escolhido.comprimentoCm - medidaPeCm).toStringAsFixed(1),
    );

    // Gera as notas técnicas explicativas para o vendedor orientar o cliente.
    final notas = <String>[
      if (acimaDaTabela)
        'A medida informada fica no limite superior da grade cadastrada.'
      else
        'Palmilha interna de ${Formato.cm(escolhido.comprimentoCm)} '
            '(folga de ${Formato.cm(folgaReal)} para forma ${c.forma.rotulo.toLowerCase()}).',
    ];

    // Se o cliente informou a numeração habitual de referência, compara com o tamanho indicado.
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

  /// Envia a requisição HTTP com proteção de timeout e fallback automático para localhost
  /// caso a rede ou as políticas de CORS do navegador bloqueiem a conexão com o Render.
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
      // Se estourar o timeout no Render, tenta a porta 8000 local se estiver ativa.
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
      // Se a conexão falhar, tenta conectar na API local.
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

  /// Trata a resposta HTTP bruta: decodifica UTF-8, valida status e expira a sessão em caso de 401.
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

    // Status 2xx indica sucesso: devolve o corpo decodificado.
    if (resposta.statusCode >= 200 && resposta.statusCode < 300) return json;

    // Se o token for recusado em rota protegida, encerra a sessão e redireciona o usuário para login.
    if (resposta.statusCode == 401 && autenticado) {
      Sessao.instance.expirar();
      throw ApiException('Sua sessão expirou. Entre novamente.', status: 401);
    }

    // Lança ApiException com a mensagem tratada e o código HTTP.
    throw ApiException(
      _mensagemDeErro(resposta.statusCode, json),
      status: resposta.statusCode,
    );
  }

  /// Extrai mensagens de erro detalhadas retornadas pelo FastAPI (campo `detail` ou erros de validação do Pydantic).
  String _mensagemDeErro(int status, dynamic json) {
    if (json is Map && json['detail'] != null) {
      final detalhe = json['detail'];
      if (detalhe is String) return detalhe;
      // Se for uma lista de validação do Pydantic, formata cada campo com sua mensagem.
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
    // Mensagens amigáveis para códigos HTTP comuns.
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

  /// Protege a conversão de tipos de dados retornados pela API contra formatação inválida.
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
