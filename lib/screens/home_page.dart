// Importa os componentes gráficos do Flutter
import 'package:flutter/material.dart';
// Importa o aplicativo principal para alternar tema
import '../main.dart';
// Importa o modelo de calçado
import '../models/calcado.dart';
// Importa o serviço de conexão com a API
import '../services/api_service.dart';
// Importa o tema e as cores
import '../theme/app_theme.dart';
// Importa o cartão individual de calçado
import '../widgets/cartao_calcado.dart';
// Importa o botão de perfil de usuário da AppBar
import '../widgets/logo_loja.dart';
// Importa a tela de cadastro para adicionar novos modelos
import 'cadastro_page.dart';
// Importa a tela de detalhes do calçado
import 'detalhe_page.dart';

/// Enum local para mapear o status visual de conexão com a API
enum _StatusApi { conectando, online, offline }

/// Tela de listagem de catálogo com pesquisa e filtros por tipo (Tênis e Chuteiras).
class HomePage extends StatefulWidget {
  // Construtor constante da página
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Lista com todos os calçados retornados pela API
  List<Calcado> _calcados = [];

  // Flag indicadora de requisição de listagem em andamento
  bool _carregando = true;

  // Mensagem de erro caso a API esteja inacessível
  String? _erro;

  // Filtro de categoria esportiva selecionado (Tênis, Chuteira ou Todos)
  TipoCalcado? _filtroTipo;

  // Texto digitado na barra de pesquisa
  String _busca = '';

  // Controlador de texto do campo de busca
  final _buscaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Dispara a busca inicial dos dados na API ao inicializar a tela
    _carregar();
  }

  @override
  void dispose() {
    // Descarta o controlador de busca da memória
    _buscaController.dispose();
    super.dispose();
  }

  /// Busca a lista atualizada de calçados diretamente na API
  Future<void> _carregar({bool silencioso = false}) async {
    // Se não for silencioso, exibe o spinner de carregamento
    if (!silencioso) setState(() => _carregando = true);
    try {
      // Dispara a requisição de listagem de calçados
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

  /// Retorna o status atual de conectividade com a API
  _StatusApi get _status {
    if (_carregando) return _StatusApi.conectando;
    return _erro == null ? _StatusApi.online : _StatusApi.offline;
  }

  /// Indica se existem dados válidos carregados
  bool get _temDados => !_carregando && _erro == null && _calcados.isNotEmpty;

  /// Retorna a lista de calçados filtrada pelo termo de busca e pelo tipo esportivo
  List<Calcado> get _visiveis {
    final termo = _busca.trim().toLowerCase();
    return _calcados.where((c) {
      // Filtra por categoria esportiva caso esteja selecionada
      if (_filtroTipo != null && c.tipo != _filtroTipo) return false;
      // Filtra por nome do modelo ou nome da marca
      return termo.isEmpty ||
          c.nome.toLowerCase().contains(termo) ||
          c.marca.toLowerCase().contains(termo);
    }).toList();
  }

  /// Exibe um aviso temporário (SnackBar) na parte inferior da tela
  void _avisar(String mensagem) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem), duration: const Duration(seconds: 2)));
  }

  /// Ação executada após retornar de uma tela filha (recarrega os dados silenciosamente)
  Future<void> _aposVoltar(String? mensagem) async {
    if (!mounted) return;
    if (mensagem != null) _avisar(mensagem);
    await _carregar(silencioso: true);
  }

  /// Abre a tela de detalhes do calçado
  Future<void> _abrirDetalhe(Calcado calcado) async {
    final resultado = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => DetalhePage(calcado: calcado)),
    );
    await _aposVoltar(resultado);
  }

  /// Abre a tela de cadastro de novos modelos
  Future<void> _abrirCadastro() async {
    final resultado = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CadastroPage()),
    );
    await _aposVoltar(resultado);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 20,
        title: Row(
          children: [
            // Ícone quadrado da régua
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.straighten_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            // Título e subtítulo da AppBar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LandView Stock',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: context.textStrong,
                  ),
                ),
                Text(
                  'Land View · Artigos Esportivos',
                  style: TextStyle(fontSize: 12, color: context.textMuted),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Botão para recarregar a lista manualmente
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'Atualizar lista',
            onPressed: _carregando ? null : () => _carregar(),
          ),
          // Botão para alternar o tema claro/escuro
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 21),
            tooltip: isDark ? 'Usar tema claro' : 'Usar tema escuro',
            onPressed: () {
              MyApp.themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          // Botão de perfil de usuário
          const MarcaAppBar(),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: context.hairline, height: 1),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Painel superior com contagem de modelos e status da conexão
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: _PainelCatalogo(
                  total: _calcados.length,
                  tenis: _calcados.where((c) => c.tipo == TipoCalcado.tenis).length,
                  chuteiras: _calcados.where((c) => c.tipo == TipoCalcado.chuteira).length,
                  status: _status,
                ),
              ),
              // Campo de busca e filtros de categoria (só exibe se houver dados)
              if (_temDados) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: TextField(
                    controller: _buscaController,
                    onChanged: (v) => setState(() => _busca = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar por modelo ou marca',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _busca.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _buscaController.clear();
                                setState(() => _busca = '');
                              },
                            ),
                    ),
                  ),
                ),
                // Chips horizontais de filtro de tipo esportivo
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _chip('Todos', null),
                      _chip('Tênis', TipoCalcado.tenis),
                      _chip('Chuteiras', TipoCalcado.chuteira),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              // Lista rolável de calçados ou estados de carregamento/vazio
              Expanded(child: _conteudo()),
            ],
          ),
        ),
      ),
      // Botão flutuante para cadastrar novo modelo
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirCadastro,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Novo modelo', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  /// Chip individual para filtro de categoria
  Widget _chip(String rotulo, TipoCalcado? tipo) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(rotulo),
        selected: _filtroTipo == tipo,
        showCheckmark: false,
        selectedColor: AppColors.brand.withValues(alpha: 0.16),
        side: BorderSide(color: context.hairline),
        onSelected: (_) => setState(() => _filtroTipo = tipo),
      ),
    );
  }

  /// Constrói o corpo principal da tela de acordo com o estado atual
  Widget _conteudo() {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_erro != null) return _EstadoErro(mensagem: _erro!, aoTentar: () => _carregar());
    if (_calcados.isEmpty) return _EstadoVazio(aoCadastrar: _abrirCadastro);

    final lista = _visiveis;
    if (lista.isEmpty) {
      return Center(
        child: Text(
          'Nenhum modelo encontrado.',
          style: TextStyle(fontSize: 14, color: context.textMuted),
        ),
      );
    }

    // Lista com suporte a pull-to-refresh
    return RefreshIndicator(
      onRefresh: () => _carregar(silencioso: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        itemCount: lista.length,
        itemBuilder: (context, i) => CartaoCalcado(
          calcado: lista[i],
          onTap: () => _abrirDetalhe(lista[i]),
        ),
      ),
    );
  }
}

/// Painel escuro do topo com indicadores de catálogo e conexão
class _PainelCatalogo extends StatelessWidget {
  final int total;
  final int tenis;
  final int chuteiras;
  final _StatusApi status;

  const _PainelCatalogo({
    required this.total,
    required this.tenis,
    required this.chuteiras,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    // Configura texto e cor do indicador de status
    final (Color corStatus, String textoStatus) = switch (status) {
      _StatusApi.conectando => (AppColors.hazard, 'Conectando…'),
      _StatusApi.online => (AppColors.brandLight, 'API conectada'),
      _StatusApi.offline => (AppColors.danger, 'Sem conexão'),
    };

    final online = status == _StatusApi.online;
    String n(int v) => online ? '$v' : '—';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 3, color: AppColors.brand),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Modelos no catálogo',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: corStatus, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          textoStatus,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  n(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _Leitura(rotulo: 'Tênis', valor: n(tenis)),
                    Container(
                      width: 1,
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    _Leitura(rotulo: 'Chuteiras', valor: n(chuteiras)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  ApiService.baseUrl,
                  style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha de leitura com valor em destaque e rótulo explicativo
class _Leitura extends StatelessWidget {
  final String rotulo;
  final String valor;
  const _Leitura({required this.rotulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          valor,
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        Text(
          rotulo,
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
        ),
      ],
    );
  }
}

/// Estado de erro local
class _EstadoErro extends StatelessWidget {
  final String mensagem;
  final VoidCallback aoTentar;
  const _EstadoErro({required this.mensagem, required this.aoTentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: context.textMuted),
            const SizedBox(height: 14),
            Text(
              'Não foi possível carregar o catálogo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.textStrong,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.4, color: context.textMuted),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: aoTentar,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado vazio local
class _EstadoVazio extends StatelessWidget {
  final VoidCallback aoCadastrar;
  const _EstadoVazio({required this.aoCadastrar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 40, color: context.textMuted),
            const SizedBox(height: 14),
            Text(
              'Nenhum modelo cadastrado',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.textStrong,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cadastre o primeiro tênis ou chuteira com a tabela de medidas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: context.textMuted),
            ),
            const SizedBox(height: 18),
            OutlinedButton(onPressed: aoCadastrar, child: const Text('Cadastrar modelo')),
          ],
        ),
      ),
    );
  }
}
