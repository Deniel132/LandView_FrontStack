// Importa os componentes e estilos visuais do Flutter
import 'package:flutter/material.dart';
// Importa o modelo de calçado
import '../models/calcado.dart';
// Importa o cliente de API para requisições de listagem
import '../services/api_service.dart';
// Importa o serviço de sessão para controle de perfis de usuário
import '../services/sessao.dart';
// Importa o tema e cores do aplicativo
import '../theme/app_theme.dart';
// Importa utilitários de formatação de moeda e números
import '../utils/formato.dart';
// Importa o cartão visual de calçado
import '../widgets/cartao_calcado.dart';
// Importa os componentes de estado vazio e erro
import '../widgets/estados.dart';
// Importa o botão de perfil de usuário na AppBar
import '../widgets/logo_loja.dart';
// Importa a tela de cadastro para criação de modelos
import 'cadastro_page.dart';
// Importa a tela de detalhes do calçado
import 'detalhe_page.dart';

/// Opções de filtro por situação de estoque
enum _FiltroEstoque {
  todos('Todos'),
  baixo('Estoque baixo'),
  esgotado('Esgotados'),
  excesso('Em excesso');

  final String rotulo;
  const _FiltroEstoque(this.rotulo);
}

/// Opções de ordenação do catálogo
enum _Ordenacao {
  padrao('Relevância'),
  nomeAz('Nome (A–Z)'),
  menorEstoque('Menor estoque'),
  maiorEstoque('Maior estoque'),
  menorPreco('Menor preço'),
  maiorPreco('Maior preço');

  final String rotulo;
  const _Ordenacao(this.rotulo);
}

/// Tela de Catálogo Geral e Estoque: permite buscar por modelo ou marca, filtrar por tipo esportivo
/// (Tênis/Chuteira) e por situação de estoque (baixo, esgotado, excesso), ordenar por preço/estoque/nome,
/// visualizar métricas gerais de unidades e valor imobilizado e navegar para o detalhe ou cadastro.
class CatalogoPage extends StatefulWidget {
  /// Controla se a tela exibe sua própria AppBar superior (falso quando embutida na Navbar principal)
  final bool mostrarAppBar;

  /// Notificador opcional que dispara atualização silenciosa quando o botão Atualizar da Navbar é pressionado
  final ValueNotifier<int>? gatilhoAtualizacao;

  // Construtor constante da página de catálogo com suporte ao modo embutido na Navbar
  const CatalogoPage({
    super.key,
    this.mostrarAppBar = true,
    this.gatilhoAtualizacao,
  });

  @override
  State<CatalogoPage> createState() => _CatalogoPageState();
}

class _CatalogoPageState extends State<CatalogoPage> {
  // Lista em memória com todos os calçados retornados pelo backend
  List<Calcado> _calcados = [];

  // Flag que controla a exibição do spinner de carregamento inicial
  bool _carregando = true;

  // Flag que trava novos toques enquanto navega para outra tela (evita rotas duplicadas)
  bool _navegando = false;

  // Mensagem de erro caso a requisição falhe
  String? _erro;

  // Filtro selecionado por tipo esportivo (Tênis, Chuteiras ou Todos)
  TipoCalcado? _filtroTipo;

  // Filtro selecionado por situação de estoque
  _FiltroEstoque _filtroEstoque = _FiltroEstoque.todos;

  // Critério de ordenação selecionado
  _Ordenacao _ordenacao = _Ordenacao.padrao;

  // Termo digitado na barra de pesquisa
  String _busca = '';

  // Controlador de texto do campo de busca
  final _buscaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Registra o ouvinte de atualização da Navbar quando embutida
    widget.gatilhoAtualizacao?.addListener(_aoDispararGatilho);
    // Dispara a requisição de busca de calçados ao entrar na tela
    _carregar();
  }

  @override
  void didUpdateWidget(covariant CatalogoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Atualiza o ouvinte caso o notificador seja substituído
    if (oldWidget.gatilhoAtualizacao != widget.gatilhoAtualizacao) {
      oldWidget.gatilhoAtualizacao?.removeListener(_aoDispararGatilho);
      widget.gatilhoAtualizacao?.addListener(_aoDispararGatilho);
    }
  }

  @override
  void dispose() {
    // Remove o ouvinte da Navbar ao desmontar a tela
    widget.gatilhoAtualizacao?.removeListener(_aoDispararGatilho);
    // Libera a memória do controlador de busca
    _buscaController.dispose();
    super.dispose();
  }

  /// Recarrega os modelos do catálogo quando a Navbar solicitar atualização
  void _aoDispararGatilho() {
    // Atualiza silenciosamente se já houver modelos na tela
    _carregar(silencioso: _calcados.isNotEmpty);
  }

  /// Busca a lista atualizada de calçados na API (fonte da verdade)
  Future<void> _carregar({bool silencioso = false}) async {
    // Se não for atualização em background, exibe loading visual
    if (!silencioso) setState(() => _carregando = true);
    try {
      // Dispara a requisição para listar calçados
      final lista = await ApiService.instance.listar();
      if (!mounted) return;
      setState(() {
        _calcados = lista;
        _erro = null;
        _carregando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.mensagem;
        _carregando = false;
      });
    }
  }

  /// Indica se existem calçados carregados na lista
  bool get _temDados => !_carregando && _erro == null && _calcados.isNotEmpty;

  /// Indica se há algum filtro, ordenação ou busca ativa no momento
  bool get _temFiltroAtivo =>
      _filtroTipo != null ||
      _filtroEstoque != _FiltroEstoque.todos ||
      _ordenacao != _Ordenacao.padrao ||
      _busca.trim().isNotEmpty;

  /// Limpa todos os filtros e a barra de pesquisa
  void _limparFiltros() {
    // Limpa o texto digitado no controlador de busca
    _buscaController.clear();
    // Restaura todos os estados de filtro e ordenação para o padrão inicial
    setState(() {
      _busca = '';
      _filtroTipo = null;
      _filtroEstoque = _FiltroEstoque.todos;
      _ordenacao = _Ordenacao.padrao;
    });
  }

  /// Retorna os calçados que atendem aos filtros de busca, categoria e estoque, já ordenados
  List<Calcado> get _visiveis {
    // Normaliza o termo pesquisado para letras minúsculas sem espaços nas pontas
    final termo = _busca.trim().toLowerCase();

    // Filtra a lista de calçados
    final filtrados = _calcados.where((c) {
      // Filtra por tipo esportivo (Tênis ou Chuteira)
      if (_filtroTipo != null && c.tipo != _filtroTipo) return false;

      // Filtra por situação de estoque garantindo separação exata entre baixo (1 a 5) e esgotado (0)
      switch (_filtroEstoque) {
        case _FiltroEstoque.todos:
          break;
        case _FiltroEstoque.baixo:
          // Exibe apenas modelos com estoque baixo (entre 1 e 5 unidades, sem misturar esgotados)
          if (!c.estoqueBaixo) return false;
        case _FiltroEstoque.esgotado:
          // Exibe apenas modelos completamente sem estoque (0 unidades)
          if (!c.esgotado) return false;
        case _FiltroEstoque.excesso:
          // Exibe apenas modelos com estoque elevado (40 unidades ou mais)
          if (!c.estoqueAlto) return false;
      }

      // Filtra por nome do modelo ou nome da marca
      return termo.isEmpty ||
          c.nome.toLowerCase().contains(termo) ||
          c.marca.toLowerCase().contains(termo);
    }).toList();

    // Aplica a ordenação selecionada com desempate alfabético para estabilidade visual
    switch (_ordenacao) {
      // Mantém a ordem original vinda do banco de dados
      case _Ordenacao.padrao:
        break;
      // Ordena alfabeticamente pelo nome do calçado (A a Z)
      case _Ordenacao.nomeAz:
        filtrados.sort(
          (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
        );
      // Ordena do menor para o maior saldo de estoque (desempatando por nome)
      case _Ordenacao.menorEstoque:
        filtrados.sort((a, b) {
          // Compara a quantidade em estoque de cada calçado
          final cmp = a.estoque.compareTo(b.estoque);
          // Se o estoque for diferente retorna a comparação; se empatar, ordena por nome
          return cmp != 0
              ? cmp
              : a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
        });
      // Ordena do maior para o menor saldo de estoque (desempatando por nome)
      case _Ordenacao.maiorEstoque:
        filtrados.sort((a, b) {
          // Compara a quantidade em estoque em ordem decrescente
          final cmp = b.estoque.compareTo(a.estoque);
          // Se o estoque for diferente retorna a comparação; se empatar, ordena por nome
          return cmp != 0
              ? cmp
              : a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
        });
      // Ordena do menor para o maior preço unitário (desempatando por nome)
      case _Ordenacao.menorPreco:
        filtrados.sort((a, b) {
          // Compara o preço unitário em ordem crescente
          final cmp = a.preco.compareTo(b.preco);
          // Se o preço for diferente retorna a comparação; se empatar, ordena por nome
          return cmp != 0
              ? cmp
              : a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
        });
      // Ordena do maior para o menor preço unitário (desempatando por nome)
      case _Ordenacao.maiorPreco:
        filtrados.sort((a, b) {
          // Compara o preço unitário em ordem decrescente
          final cmp = b.preco.compareTo(a.preco);
          // Se o preço for diferente retorna a comparação; se empatar, ordena por nome
          return cmp != 0
              ? cmp
              : a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
        });
    }
    // Devolve a lista filtrada e ordenada pronta para exibição
    return filtrados;
  }

  /// Exibe um aviso temporário (SnackBar) na tela
  void _avisar(String mensagem) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(mensagem), duration: const Duration(seconds: 2)),
      );
  }

  /// Ação disparada ao retornar de uma tela filha (recarrega os calçados)
  Future<void> _aposVoltar(String? mensagem) async {
    if (!mounted) return;
    if (mensagem != null) _avisar(mensagem);
    await _carregar(silencioso: true);
  }

  /// Abre a tela de detalhes do calçado evitando abertura duplicada em cliques múltiplos
  Future<void> _abrirDetalhe(Calcado calcado) async {
    // Se já está navegando para outro produto ou tela, ignora o toque repetido
    if (_navegando) return;
    // Ativa a trava de navegação
    _navegando = true;
    try {
      // Empilha a tela de detalhes e aguarda eventual mensagem de retorno
      final resultado = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => DetalhePage(calcado: calcado)),
      );
      await _aposVoltar(resultado);
    } finally {
      // Libera a trava ao retornar para o catálogo
      _navegando = false;
    }
  }

  /// Abre a tela de cadastro para inclusão de novo produto evitando abertura duplicada
  Future<void> _abrirCadastro() async {
    // Impede abrir múltiplas telas de cadastro por duplo clique
    if (_navegando) return;
    // Ativa a trava de navegação
    _navegando = true;
    try {
      // Empilha a tela de cadastro e aguarda eventual mensagem de sucesso
      final resultado = await Navigator.of(
        context,
      ).push<String>(MaterialPageRoute(builder: (_) => const CadastroPage()));
      await _aposVoltar(resultado);
    } finally {
      // Libera a trava ao retornar para o catálogo
      _navegando = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Identifica se a altura disponível é compacta (telas baixas)
    final compacto = MediaQuery.sizeOf(context).height < 520;

    // Calcula a soma total de unidades de todos os calçados
    final totalUnidades = _calcados.fold<int>(0, (s, c) => s + c.estoque);

    // Calcula o valor monetário imobilizado total em estoque
    final valorTotalEstoque = _calcados.fold<double>(
      0,
      (s, c) => s + c.valorTotalEstoque,
    );

    return Scaffold(
      // Oculta a AppBar própria quando embutida na Navbar principal
      appBar: widget.mostrarAppBar
          ? AppBar(
              toolbarHeight: 68,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Título principal com truncamento seguro em telas estreitas
                  Text(
                    'Catálogo & Estoque',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: context.textStrong,
                    ),
                  ),
                  // Subtítulo com truncamento seguro para evitar quebra em celulares
                  Text(
                    'Gestão de modelos, estoque e tabela de medidas',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: context.textMuted),
                  ),
                ],
              ),
              actions: [
                // Botão para atualizar a listagem
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 22),
                  tooltip: 'Atualizar lista',
                  onPressed: _carregando ? null : () => _carregar(),
                ),
                // Botão reutilizável para alternar tema claro/escuro
                const BotaoAlternarTema(),
                // Botão de perfil do usuário
                const MarcaAppBar(),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: context.hairline, height: 1),
              ),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Painel superior com estatísticas resumidas
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: _PainelCatalogo(
                  total: _calcados.length,
                  tenis: _calcados
                      .where((c) => c.tipo == TipoCalcado.tenis)
                      .length,
                  chuteiras: _calcados
                      .where((c) => c.tipo == TipoCalcado.chuteira)
                      .length,
                  unidades: totalUnidades,
                  valorEstoque: valorTotalEstoque,
                  online: !_carregando && _erro == null,
                  compacto: compacto,
                ),
              ),
              // Campo de busca e menu de ordenação
              if (_temDados) ...[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    compacto ? 6 : 12,
                    16,
                    compacto ? 6 : 10,
                  ),
                  child: Row(
                    children: [
                      // Barra de pesquisa
                      Expanded(
                        child: TextField(
                          controller: _buscaController,
                          onChanged: (v) => setState(() => _busca = v),
                          decoration: InputDecoration(
                            hintText: 'Buscar por modelo ou marca',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _busca.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Limpar busca',
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () {
                                      _buscaController.clear();
                                      setState(() => _busca = '');
                                    },
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Menu de seleção do critério de ordenação
                      PopupMenuButton<_Ordenacao>(
                        tooltip: 'Ordenar catálogo',
                        initialValue: _ordenacao,
                        onSelected: (v) => setState(() => _ordenacao = v),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                        ),
                        itemBuilder: (_) => [
                          for (final ord in _Ordenacao.values)
                            PopupMenuItem<_Ordenacao>(
                              value: ord,
                              child: Row(
                                children: [
                                  Icon(
                                    _ordenacao == ord
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    size: 18,
                                    color: _ordenacao == ord
                                        ? context.accent
                                        : context.textMuted,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(ord.rotulo),
                                ],
                              ),
                            ),
                        ],
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: _ordenacao != _Ordenacao.padrao
                                ? AppColors.brand.withValues(alpha: 0.14)
                                : context.cardSurface,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius,
                            ),
                            border: Border.all(
                              color: _ordenacao != _Ordenacao.padrao
                                  ? context.accent
                                  : context.hairline,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sort_rounded,
                                size: 20,
                                color: _ordenacao != _Ordenacao.padrao
                                    ? context.accent
                                    : context.textMuted,
                              ),
                              if (!compacto) ...[
                                const SizedBox(width: 6),
                                Text(
                                  _ordenacao.rotulo,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _ordenacao != _Ordenacao.padrao
                                        ? context.accent
                                        : context.textStrong,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Linha rolável com filtros de tipo e filtros de situação de estoque
                SizedBox(
                  height: compacto ? 36 : 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _chipTipo('Todos', null),
                      _chipTipo('Tênis', TipoCalcado.tenis),
                      _chipTipo('Chuteiras', TipoCalcado.chuteira),
                      Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        color: context.hairline,
                      ),
                      for (final f in _FiltroEstoque.values)
                        if (f != _FiltroEstoque.todos) _chipEstoque(f),
                    ],
                  ),
                ),
                SizedBox(height: compacto ? 4 : 10),
              ],
              // Lista de resultados
              Expanded(child: _conteudo()),
            ],
          ),
        ),
      ),
      // Botão flutuante para adicionar novo calçado (disponível somente para Dono/Gerente)
      floatingActionButton: (Sessao.instance.usuario?.podeGerenciarProdutos ?? false)
          ? FloatingActionButton.extended(
              onPressed: _abrirCadastro,
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Novo modelo',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  /// Chip individual para filtrar por categoria esportiva ou limpar filtros ("Todos")
  Widget _chipTipo(String rotulo, TipoCalcado? tipo) {
    // O chip "Todos" (tipo == null) só fica marcado quando nenhum filtro de tipo ou de estoque está ativo
    final selecionado = tipo == null
        ? (_filtroTipo == null && _filtroEstoque == _FiltroEstoque.todos)
        : _filtroTipo == tipo;
    // Retorna o chip estilizado com espaçamento lateral
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(rotulo),
        selected: selecionado,
        showCheckmark: false,
        selectedColor: AppColors.brand.withValues(alpha: 0.16),
        side: BorderSide(color: context.hairline),
        onSelected: (_) => setState(() {
          // Se clicou em "Todos" ou desmarcou o tipo atual, limpa tipo e filtro de estoque
          if (tipo == null || _filtroTipo == tipo) {
            _filtroTipo = null;
            _filtroEstoque = _FiltroEstoque.todos;
          } else {
            // Aplica o tipo escolhido e reseta o filtro de estoque para evitar combinação invisível
            _filtroTipo = tipo;
            _filtroEstoque = _FiltroEstoque.todos;
          }
        }),
      ),
    );
  }

  /// Chip individual para filtrar por condição de estoque
  Widget _chipEstoque(_FiltroEstoque filtro) {
    // Verifica se este filtro de estoque específico está selecionado
    final selecionado = _filtroEstoque == filtro;
    // Retorna o chip estilizado com espaçamento lateral
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(filtro.rotulo),
        selected: selecionado,
        showCheckmark: false,
        selectedColor: AppColors.hazard.withValues(alpha: 0.18),
        side: BorderSide(color: context.hairline),
        onSelected: (_) => setState(() {
          // Alterna o filtro de estoque clicado e limpa o filtro de tipo anterior para exibir todos os itens daquela condição
          _filtroEstoque = selecionado ? _FiltroEstoque.todos : filtro;
          _filtroTipo = null;
        }),
      ),
    );
  }

  /// Constrói o corpo da página dependendo do estado da lista
  Widget _conteudo() {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_erro != null) {
      return EstadoErro(
        titulo: 'Não foi possível carregar o catálogo',
        mensagem: _erro!,
        aoTentar: () => _carregar(),
      );
    }
    if (_calcados.isEmpty) {
      return EstadoVazio(
        icone: Icons.inventory_2_outlined,
        titulo: 'Nenhum modelo cadastrado',
        subtitulo:
            'Cadastre o primeiro tênis ou chuteira com a tabela de medidas.',
        rotuloAcao: 'Cadastrar modelo',
        aoAcionar: _abrirCadastro,
      );
    }

    final lista = _visiveis;
    if (lista.isEmpty) {
      return EstadoVazio(
        icone: Icons.search_off_rounded,
        titulo: 'Nenhum modelo encontrado',
        subtitulo: 'Ajuste os termos da busca ou limpe os filtros selecionados.',
        rotuloAcao: _temFiltroAtivo ? 'Limpar filtros' : null,
        aoAcionar: _temFiltroAtivo ? _limparFiltros : null,
      );
    }

    // Lista rolável de calçados
    return RefreshIndicator(
      onRefresh: () => _carregar(silencioso: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        itemCount: lista.length,
        itemBuilder: (context, i) => CartaoCalcado(
          // Chave única por calçado para garantir atualização fiel ao alternar filtros e ordenações
          key: ValueKey(lista[i].id ?? '${lista[i].nome}_$i'),
          calcado: lista[i],
          onTap: () => _abrirDetalhe(lista[i]),
        ),
      ),
    );
  }
}

/// Painel escuro do topo com indicadores de catálogo, unidades totais e valor de estoque
class _PainelCatalogo extends StatelessWidget {
  // Quantidade total de modelos cadastrados no catálogo
  final int total;
  // Quantidade total de modelos da categoria Tênis
  final int tenis;
  // Quantidade total de modelos da categoria Chuteira
  final int chuteiras;
  // Soma de todas as unidades físicas disponíveis em estoque
  final int unidades;
  // Soma financeira total do estoque imobilizado em reais
  final double valorEstoque;
  // Indica se os dados da tela já foram carregados com sucesso sem erros
  final bool online;
  // Indica se a tela possui altura reduzida para renderizar versão enxuta
  final bool compacto;

  // Construtor constante com parâmetros obrigatórios do painel de resumo
  const _PainelCatalogo({
    required this.total,
    required this.tenis,
    required this.chuteiras,
    required this.unidades,
    required this.valorEstoque,
    required this.online,
    required this.compacto,
  });

  @override
  Widget build(BuildContext context) {
    // Função auxiliar que formata números inteiros ou exibe travessão enquanto carrega
    String n(int v) => online ? '$v' : '—';

    // Contêiner principal escuro com cantos arredondados e borda sutil
    return Container(
      decoration: BoxDecoration(
        // Cor de fundo escura característica do painel superior
        color: AppColors.ink,
        // Arredondamento amplo dos cantos
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        // Borda translúcida discreta
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      // Recorta o conteúdo interno respeitando as bordas arredondadas
      clipBehavior: Clip.antiAlias,
      // Empilha a faixa azul superior e o conteúdo textual do painel
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Faixa decorativa superior na cor azul da marca LandView
          Container(height: 3, color: AppColors.brand),
          // Renderiza layout compacto caso a altura da janela seja reduzida
          if (compacto)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Título descritivo do painel compacto
                  Text(
                    'Modelos no catálogo',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  // Espaçamento vertical curto
                  const SizedBox(height: 4),
                  // Resumo em linha única com contagens de modelos, tipos e unidades
                  Text(
                    '${n(total)} modelos · ${n(tenis)} tênis · ${n(chuteiras)} chuteiras · ${n(unidades)} un.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )
          // Renderiza layout completo padrão em telas normais
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rótulo superior do contador principal
                  Text(
                    'Modelos no catálogo',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                  // Espaçamento entre o rótulo e o número grande
                  const SizedBox(height: 6),
                  // Quantidade total de modelos em destaque tipográfico
                  Text(
                    n(total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  // Espaçamento antes das métricas secundárias
                  const SizedBox(height: 14),
                  // Agrupamento responsivo das métricas detalhadas do estoque
                  Wrap(
                    spacing: 20,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Métrica de quantidade de tênis
                      _Leitura(rotulo: 'Tênis', valor: n(tenis)),
                      // Divisor vertical sutil
                      const _DivisorVertical(),
                      // Métrica de quantidade de chuteiras
                      _Leitura(rotulo: 'Chuteiras', valor: n(chuteiras)),
                      // Divisor vertical sutil
                      const _DivisorVertical(),
                      // Métrica do total de pares/unidades em estoque
                      _Leitura(rotulo: 'Unidades', valor: n(unidades)),
                      // Divisor vertical sutil
                      const _DivisorVertical(),
                      // Métrica do valor financeiro total acumulado em estoque
                      _Leitura(
                        rotulo: 'Valor em estoque',
                        valor: online ? Formato.real(valorEstoque) : '—',
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Linha divisória vertical utilizada entre as métricas do painel escuro
class _DivisorVertical extends StatelessWidget {
  // Construtor constante do divisor vertical
  const _DivisorVertical();

  @override
  Widget build(BuildContext context) {
    // Caixa fina de 1px de largura por 28px de altura com branco translúcido
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.12),
    );
  }
}

/// Bloco de leitura de métrica contendo valor em destaque e rótulo descritivo abaixo
class _Leitura extends StatelessWidget {
  // Rótulo textual da métrica (ex: "Tênis", "Unidades")
  final String rotulo;
  // Valor formatado da métrica
  final String valor;
  // Construtor constante do bloco de leitura
  const _Leitura({required this.rotulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    // Empilha o valor numérico acima do rótulo descritivo
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Exibe o valor principal em branco seminegrito
        Text(
          valor,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        // Exibe o rótulo secundário com opacidade suave
        Text(
          rotulo,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
