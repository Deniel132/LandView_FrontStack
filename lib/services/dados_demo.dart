// Importa o modelo de dados de calçado (nome, marca, preço, estoque, etc.)
import '../models/calcado.dart';
// Importa os modelos do dashboard (resumos de estoque, mais vendidos, extremos)
import '../models/dashboard.dart';
// Importa o modelo que representa o resultado da recomendação de tamanho
import '../models/recomendacao.dart';
// Importa o modelo que representa o histórico de saídas/vendas de estoque
import '../models/saida_estoque.dart';
// Importa o modelo de usuário logado (id, nome, e-mail, perfil/role)
import '../models/usuario.dart';
// Importa o modelo que detalha o comprovante da venda realizada
import '../models/venda.dart';
// Importa utilitários de formatação de medidas, moeda e textos
import '../utils/formato.dart';
// Importa a classe padronizada de exceções da camada de API
import 'api_exception.dart';

/// Classe que simula todas as respostas da API quando o app roda em modo demonstração:
///   flutter run --dart-define=DEMO=true
///
/// Serve para demonstrar e testar todas as telas sem depender do backend Python.
/// Todos os dados são armazenados na memória RAM e reiniciados ao fechar o app.
class DadosDemo {
  // Construtor privado para garantir o padrão Singleton (apenas uma instância no app)
  DadosDemo._();

  // Instância única estática acessível globalmente via DadosDemo.instance
  static final DadosDemo instance = DadosDemo._();

  // Simula um tempo de resposta de rede de 280ms para os loadings visuais aparecerem
  static const _latencia = Duration(milliseconds: 280);

  // Limite numérico abaixo do qual um produto é classificado como "estoque baixo"
  static const limiteBaixo = 5;

  // Limite numérico acima do qual um produto é classificado como "estoque com excesso"
  static const limiteAlto = 40;

  // Dicionário em memória que mapeia o ID do calçado para o total de vendas nos últimos 30 dias
  final Map<int, int> _vendas = {};

  // Conjunto de e-mails já cadastrados para evitar duplicidades na tela de cadastro
  final Set<String> _contasCadastradas = {'cliente@loja.com'};

  // Lista em memória com o histórico cronológico de saídas e vendas do estoque
  final List<SaidaEstoque> _saidas = [];

  // Lista dinâmica com todos os calçados em memória, populada inicialmente por _semear()
  late List<Calcado> _lista = _semear();

  // Contador sequencial para gerar novos IDs ao cadastrar calçados
  int _proximoId = 100;

  // Contador sequencial para gerar IDs de cada venda realizada
  int _proximaVendaId = 1;

  /// Reinicia todos os dados em memória para o estado original (muito útil em testes).
  void resetar() {
    // Limpa o mapa de contagem de vendas
    _vendas.clear();
    // Limpa a lista de saídas de estoque
    _saidas.clear();
    // Restaura a lista de contas apenas com a conta demo inicial
    _contasCadastradas
      ..clear()
      ..add('cliente@loja.com');
    // Recria a lista inicial padrão de calçados
    _lista = _semear();
    // Reseta o próximo ID de produto para 100
    _proximoId = 100;
    // Reseta o próximo ID de venda para 1
    _proximaVendaId = 1;
  }

  /// Adiciona uma pequena espera assíncrona para simular o comportamento de uma requisição HTTP.
  Future<T> _atraso<T>(T Function() acao) async {
    // Aguarda 280 milissegundos
    await Future<void>.delayed(_latencia);
    // Executa a função repassada e devolve o seu resultado
    return acao();
  }

  // ---------------------------------------------------------------- dados

  /// Gera uma tabela padrão de medidas (do tamanho 37 ao 45) com base na forma do calçado.
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
    // Devolve a grade gerada a partir desse tamanho base
    return _tabela(base37);
  }

  /// Gera a lista de medidas do 37 ao 45, onde cada número aumenta ~0,667 cm (ponto francês padrão).
  static List<MedidaTamanho> _tabela(double comp37) => [
    // Laço de repetição que itera do número 37 até o número 45
    for (var n = 37; n <= 45; n++)
      MedidaTamanho(
        // Numeração do calçado (ex: 37.0, 38.0, ...)
        numeracao: n.toDouble(),
        // Calcula o comprimento interno somando a fração de crescimento por número e arredondando para 1 casa
        comprimentoCm: double.parse(
          (comp37 + (n - 37) * 0.667).toStringAsFixed(1),
        ),
      ),
  ];

  /// Popula a lista inicial de calçados com dados de teste diversificados.
  List<Calcado> _semear() {
    // Função auxiliar interna para instanciar um calçado com menos repetição de código
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
      // Guarda a quantidade de vendas inicial no mapa de vendas
      _vendas[id] = vendas;
      // Retorna o objeto calçado devidamente preenchido
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

    // Atalhos para os tipos de calçado
    const t = TipoCalcado.tenis, ch = TipoCalcado.chuteira;
    // Atalhos para as formas do calçado
    const e = FormaCalcado.estreita,
        p = FormaCalcado.padrao,
        l = FormaCalcado.larga;

    // Retorna a lista contendo 8 calçados iniciais cadastrados na demonstração
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

  /// Simula o login do usuário, gerando um nome amigável a partir do endereço de e-mail.
  Future<Usuario> login(String email) => _atraso(() {
    // Separa o texto do e-mail antes do '@' e divide por pontos, traços ou sublinhados
    final partes = email
        .trim()
        .split('@')
        .first
        .split(RegExp(r'[._-]+'))
        .where((p) => p.isNotEmpty)
        .toList();

    // Se o prefixo do e-mail for vazio, usa 'Vendedor', senão capitaliza cada palavra (Ex: joao.silva -> Joao Silva)
    final nome = partes.isEmpty
        ? 'Vendedor'
        : partes
              .map((p) => '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}')
              .join(' ');

    // Retorna o objeto de usuário simulado com perfil de vendedor
    return Usuario(
      id: 1,
      nome: nome,
      email: email.trim(),
      perfil: 'SELLER',
    );
  });

  /// Simula o cadastro de uma nova conta de usuário no sistema.
  Future<void> criarConta(
    String email,
    String senha, {
    String role = 'SELLER',
  }) => _atraso(() {
    // Normaliza o e-mail removendo espaços extras e deixando em letras minúsculas
    final normalizado = email.trim().toLowerCase();

    // Verifica se esse e-mail já foi registrado anteriormente
    if (_contasCadastradas.contains(normalizado)) {
      // Se já existir, lança exceção com código HTTP 409 (Conflito)
      throw ApiException(
        'Já existe uma conta cadastrada com este e-mail.',
        status: 409,
      );
    }

    // Se for um novo e-mail, adiciona no conjunto de contas cadastradas
    _contasCadastradas.add(normalizado);
  });

  /// Retorna uma cópia da lista atual de calçados cadastrados.
  Future<List<Calcado>> listar() => _atraso(() => List.of(_lista));

  /// Busca um calçado específico pelo seu identificador (ID).
  Future<Calcado> buscar(int id) => _atraso(() => _achar(id));

  /// Cadastra um novo calçado na lista em memória e inicializa sua contagem de vendas.
  Future<Calcado> criar(Calcado c) => _atraso(() {
    // Cria uma cópia do calçado atribuindo o próximo ID sequencial disponível
    final novo = c.copyWith(id: _proximoId++);
    // Inicializa as vendas deste novo produto com zero
    _vendas[novo.id!] = 0;
    // Adiciona o produto na lista geral de calçados
    _lista.add(novo);
    // Retorna o produto recém-criado com seu novo ID
    return novo;
  });

  /// Atualiza as informações de um calçado existente na lista.
  Future<Calcado> atualizar(Calcado c) => _atraso(() {
    // Localiza a posição do calçado na lista pelo seu ID
    final i = _lista.indexWhere((x) => x.id == c.id);
    // Se o calçado não for encontrado, lança erro HTTP 404 (Não Encontrado)
    if (i < 0) throw ApiException('Calçado não encontrado.', status: 404);
    // Substitui o registro antigo pelo atualizado
    _lista[i] = c;
    // Retorna o calçado atualizado
    return c;
  });

  /// Remove um calçado da lista em memória e deleta seu histórico de vendas.
  Future<void> excluir(int id) => _atraso(() {
    // Garante que o calçado existe antes de tentar remover (lança 404 se não achar)
    _achar(id);
    // Remove o item da lista cujo ID seja igual ao solicitado
    _lista.removeWhere((x) => x.id == id);
    // Remove o produto do mapa de vendas
    _vendas.remove(id);
  });

  /// Registra uma venda baixando o estoque e gerando a respectiva saída de auditoria.
  Future<VendaRegistrada> registrarVenda({
    required int calcadoId,
    required int quantidade,
  }) => _atraso(() {
    // Valida se a quantidade informada para venda é um valor positivo
    if (quantidade <= 0) {
      throw ApiException('A quantidade da venda deve ser maior que zero.');
    }

    // Busca o calçado no estoque para verificar a disponibilidade
    final calcado = _achar(calcadoId);

    // Verifica se a quantidade solicitada é maior que o estoque atual disponível
    if (quantidade > calcado.estoque) {
      throw ApiException(
        'Estoque insuficiente. Disponível: ${calcado.estoque} unidade(s).',
      );
    }

    // Obtém o índice do calçado na lista
    final indice = _lista.indexWhere((c) => c.id == calcadoId);

    // Cria uma cópia do calçado subtraindo a quantidade vendida do estoque
    final atualizado = calcado.copyWith(estoque: calcado.estoque - quantidade);

    // Atualiza o item na lista de produtos em memória
    _lista[indice] = atualizado;

    // Incrementa a contagem de vendas deste produto nos últimos 30 dias
    _vendas[calcadoId] = (_vendas[calcadoId] ?? 0) + quantidade;

    // Gera o ID sequencial para o registro da venda
    final vendaId = _proximaVendaId++;

    // Insere o registro de saída no início da lista de histórico para auditoria
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

    // Retorna o comprovante detalhado da venda efetuada
    return VendaRegistrada(
      id: vendaId,
      calcadoId: calcadoId,
      quantidade: quantidade,
      estoqueAtual: atualizado.estoque,
      dataVenda: DateTime.now(),
    );
  });

  /// Lista o histórico de saídas com suporte a paginação e filtros opcionais.
  Future<List<SaidaEstoque>> listarSaidas({
    int page = 1,
    int pageSize = 15,
    int? idProduct,
    int? idStock,
  }) => _atraso(() {
    // Inicia com todas as saídas registradas
    var filtradas = _saidas;

    // Aplica filtro por ID do produto se for informado
    if (idProduct != null) {
      filtradas = filtradas.where((s) => s.idProduto == idProduct).toList();
    }

    // Aplica filtro por ID do estoque se for informado
    if (idStock != null) {
      filtradas = filtradas.where((s) => s.idEstoque == idStock).toList();
    }

    // Calcula o deslocamento inicial da página requisitada
    final start = (page - 1) * pageSize;

    // Se o ponto de início ultrapassar o total de registros, retorna lista vazia
    if (start >= filtradas.length) return <SaidaEstoque>[];

    // Pula os registros anteriores e pega apenas a quantidade da página atual
    return filtradas.skip(start).take(pageSize).toList();
  });

  /// Função utilitária interna para encontrar um calçado pelo ID ou lançar exceção 404.
  Calcado _achar(int id) => _lista.firstWhere(
    (c) => c.id == id,
    orElse: () => throw ApiException('Calçado não encontrado.', status: 404),
  );

  /// Consolida e calcula todos os números e listas para exibir o Dashboard da loja.
  Future<Dashboard> dashboard() => _atraso(() {
    // Converte um objeto Calçado para o modelo resumido ItemDashboard
    ItemDashboard item(Calcado c) => ItemDashboard(
      id: c.id!,
      nome: c.nome,
      marca: c.marca,
      vendas: _vendas[c.id] ?? 0,
      estoque: c.estoque,
    );

    // Ordena os calçados em ordem crescente de estoque para identificar os extremos
    final ordenadosPorEstoque = [..._lista]
      ..sort((a, b) => a.estoque.compareTo(b.estoque));

    // Identifica o produto com a menor quantidade de estoque
    final menor = ordenadosPorEstoque.isNotEmpty ? ordenadosPorEstoque.first : null;

    // Identifica o produto com a maior quantidade de estoque
    final maior = ordenadosPorEstoque.isNotEmpty ? ordenadosPorEstoque.last : null;

    // Ordena os produtos de forma decrescente pela quantidade de vendas em 30 dias
    final vendidos = [..._lista]
      ..sort((a, b) => (_vendas[b.id] ?? 0).compareTo(_vendas[a.id] ?? 0));

    // Filtra os produtos com estoque baixo (menor ou igual a 5 unidades)
    final baixo = _lista.where((c) => c.estoque <= limiteBaixo).toList()
      ..sort((a, b) => a.estoque.compareTo(b.estoque));

    // Filtra os produtos com excesso de estoque (maior ou igual a 40 unidades)
    final alto = _lista.where((c) => c.estoque >= limiteAlto).toList()
      ..sort((a, b) => b.estoque.compareTo(a.estoque));

    // Monta e retorna o objeto consolidado com todas as métricas do Dashboard
    return Dashboard(
      // Resumo numérico com totais de modelos, unidades e alertas
      resumo: ResumoDashboard(
        // Total de modelos diferentes cadastrados
        totalModelos: _lista.length,
        // Soma de todas as unidades físicas de calçados disponíveis
        unidadesEmEstoque: _lista.fold(0, (s, c) => s + c.estoque),
        // Soma do total de vendas nos últimos 30 dias
        vendas30Dias: _vendas.values.fold(0, (s, v) => s + v),
        // Quantidade de modelos que estão com estoque baixo
        modelosAcabando: baixo.length,
        // Quantidade de modelos que estão com estoque excessivo
        modelosComExcesso: alto.length,
        // Limite configurado para alerta de estoque baixo
        limiteEstoqueBaixo: limiteBaixo,
        // Limite configurado para alerta de excesso de estoque
        limiteEstoqueAlto: limiteAlto,
      ),
      // Top 5 calçados mais vendidos com ao menos 1 venda
      maisVendidos: vendidos
          .where((c) => (_vendas[c.id] ?? 0) > 0)
          .take(5)
          .map(item)
          .toList(),
      // Lista de calçados em situação de estoque baixo
      estoqueBaixo: baixo.map(item).toList(),
      // Lista de calçados em situação de estoque alto
      estoqueAlto: alto.map(item).toList(),
      // Destaque do produto com menor estoque (alinhado com rota GET /dashboard/ do backend)
      menorEstoque: menor != null
          ? ExtremoEstoque(
              produtoId: menor.id!,
              nome: menor.nome,
              preco: menor.preco,
              quantidade: menor.estoque,
            )
          : null,
      // Destaque do produto com maior estoque (alinhado com rota GET /dashboard/ do backend)
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

  /// Algoritmo do provador virtual: calcula o tamanho ideal baseado no comprimento do pé em centímetros,
  /// aplicando tolerância pelo tipo de calçado e compensação pelo formato da forma (estreita, padrão ou larga).
  Future<Recomendacao> recomendar({
    required int calcadoId,
    required double medidaPeCm,
    double? numeracaoHabitual,
    String? marcaHabitual,
  }) => _atraso(() {
    // Busca os dados do calçado para o qual se deseja a recomendação
    final c = _achar(calcadoId);

    // Se o calçado não tiver tabela de tamanhos, retorna erro 400
    if (c.tamanhos.isEmpty) {
      throw ApiException(
        'Este calçado não possui tabela de medidas cadastrada.',
        status: 400,
      );
    }

    // Chuteiras precisam de um ajuste mais justo (folga base de 0,6 cm), tênis usam 1,0 cm
    final folgaBase = c.tipo == TipoCalcado.chuteira ? 0.6 : 1.0;

    // Compensação conforme a largura da forma: forma estreita exige mais folga (+0,3cm), forma larga exige menos (-0,2cm)
    final ajusteForma = switch (c.forma) {
      FormaCalcado.estreita => 0.3,
      FormaCalcado.padrao => 0.0,
      FormaCalcado.larga => -0.2,
    };

    // Comprimento interno de palmilha ideal calculado para este cliente
    final alvo = medidaPeCm + folgaBase + ajusteForma;

    // Tabela de tamanhos cadastrada no modelo
    final t = c.tamanhos;

    // Encontra o primeiro tamanho cuja palmilha seja maior ou igual ao tamanho alvo
    var i = t.indexWhere((m) => m.comprimentoCm >= alvo - 1e-9);

    // Verifica se a medida ultrapassa o maior número cadastrado na grade
    final acimaDaTabela = i < 0;

    // Se ultrapassar a grade, sugere o maior tamanho existente na tabela
    if (acimaDaTabela) i = t.length - 1;

    // Obtém o tamanho selecionado pelo algoritmo
    final escolhido = t[i];

    // Calcula a folga real restante entre o pé e a palmilha escolhida
    final folgaReal = double.parse(
      (escolhido.comprimentoCm - medidaPeCm).toStringAsFixed(1),
    );

    // Gera as notas explicativas para orientar o vendedor e o cliente
    final notas = <String>[
      if (acimaDaTabela)
        'A medida informada fica no limite superior da grade cadastrada.'
      else
        'Palmilha interna de ${Formato.cm(escolhido.comprimentoCm)} '
            '(folga de ${Formato.cm(folgaReal)} para forma ${c.forma.rotulo.toLowerCase()}).',
    ];

    // Se o cliente informou o tamanho que costuma usar habitualmente, compara com o recomendado
    if (numeracaoHabitual != null) {
      // Diferença numérica entre o tamanho recomendado e o habitual
      final dif = escolhido.numeracao - numeracaoHabitual;

      // Adiciona o nome da marca habitual se foi preenchida
      final refMarca = (marcaHabitual != null && marcaHabitual.isNotEmpty)
          ? ' ($marcaHabitual)'
          : '';

      // Se a diferença for de meio número ou mais, gera recomendação textual de ajuste
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

    // Retorna o resultado completo da recomendação com a numeração principal e a opção alternativa
    return Recomendacao(
      // Numeração principal sugerida
      tamanho: escolhido.numeracao,
      // Próxima numeração alternativa disponível na grade (se houver)
      alternativa: i + 1 < t.length ? t[i + 1].numeracao : null,
      // Folga real em centímetros
      folgaCm: folgaReal,
      // Texto com a justificativa técnica da recomendação
      observacao: notas.join(' '),
    );
  });
}
