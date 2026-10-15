import 'package:flutter/material.dart';
import '../main.dart';
import '../models/calcado.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cartao_calcado.dart';
import '../widgets/logo_loja.dart';
import 'cadastro_page.dart';
import 'detalhe_page.dart';

enum _StatusApi { conectando, online, offline, demonstracao }

class CatalogoPage extends StatefulWidget {
  const CatalogoPage({super.key});

  @override
  State<CatalogoPage> createState() => _CatalogoPageState();
}

class _CatalogoPageState extends State<CatalogoPage> {
  List<Calcado> _calcados = [];
  bool _carregando = true;
  String? _erro;

  TipoCalcado? _filtroTipo;
  String _busca = '';
  final _buscaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  /// Busca a lista na API. A API é a fonte da verdade: o app não guarda
  /// nada localmente, então alterações feitas pela interface Python
  /// aparecem aqui assim que a lista é recarregada.
  Future<void> _carregar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _carregando = true);
    try {
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

  _StatusApi get _status {
    if (ApiService.modoDemo) return _StatusApi.demonstracao;
    if (_carregando) return _StatusApi.conectando;
    return _erro == null ? _StatusApi.online : _StatusApi.offline;
  }

  /// Busca e filtros só fazem sentido quando existe lista para filtrar.
  bool get _temDados => !_carregando && _erro == null && _calcados.isNotEmpty;

  List<Calcado> get _visiveis {
    final termo = _busca.trim().toLowerCase();
    return _calcados.where((c) {
      if (_filtroTipo != null && c.tipo != _filtroTipo) return false;
      return termo.isEmpty ||
          c.nome.toLowerCase().contains(termo) ||
          c.marca.toLowerCase().contains(termo);
    }).toList();
  }

  void _avisar(String mensagem) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(mensagem), duration: const Duration(seconds: 2)),
      );
  }

  /// Depois de qualquer tela filha, recarrega a lista: outra pessoa pode
  /// ter alterado os dados enquanto o vendedor estava na tela de detalhe.
  Future<void> _aposVoltar(String? mensagem) async {
    if (!mounted) return;
    if (mensagem != null) _avisar(mensagem);
    await _carregar(silencioso: true);
  }

  Future<void> _abrirDetalhe(Calcado calcado) async {
    final resultado = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => DetalhePage(calcado: calcado)),
    );
    await _aposVoltar(resultado);
  }

  Future<void> _abrirCadastro() async {
    final resultado = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const CadastroPage()));
    await _aposVoltar(resultado);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final compacto = MediaQuery.sizeOf(context).height < 460;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Controle De Estoque',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: context.textStrong,
              ),
            ),
            Text(
              'Verificacao de estoque por tipo de calcados',
              style: TextStyle(fontSize: 12, color: context.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'Atualizar lista',
            onPressed: _carregando ? null : () => _carregar(),
          ),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 21,
            ),
            tooltip: isDark ? 'Usar tema claro' : 'Usar tema escuro',
            onPressed: () {
              MyApp.themeNotifier.value = isDark
                  ? ThemeMode.light
                  : ThemeMode.dark;
            },
          ),
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
                  status: _status,
                  compacto: compacto,
                ),
              ),
              if (_temDados) ...[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    compacto ? 6 : 12,
                    16,
                    compacto ? 6 : 10,
                  ),
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
                SizedBox(
                  height: compacto ? 36 : 40,
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
                SizedBox(height: compacto ? 4 : 10),
              ],
              Expanded(child: _conteudo()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirCadastro,
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'Novo modelo',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

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

  Widget _conteudo() {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_erro != null) {
      return _EstadoErro(mensagem: _erro!, aoTentar: () => _carregar());
    }
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

/// Painel escuro com a contagem do catálogo e o estado da conexão.
class _PainelCatalogo extends StatelessWidget {
  final int total;
  final int tenis;
  final int chuteiras;
  final _StatusApi status;
  final bool compacto;

  const _PainelCatalogo({
    required this.total,
    required this.tenis,
    required this.chuteiras,
    required this.status,
    required this.compacto,
  });

  @override
  Widget build(BuildContext context) {
    final (Color corStatus, String textoStatus) = switch (status) {
      _StatusApi.conectando => (AppColors.hazard, 'Conectando…'),
      _StatusApi.online => (AppColors.brandLight, 'API conectada'),
      _StatusApi.offline => (AppColors.danger, 'Sem conexão'),
      _StatusApi.demonstracao => (AppColors.infoLight, 'Demonstração'),
    };

    // Sem conexão não dá para afirmar que o catálogo está vazio:
    // mostrar "0" seria uma informação falsa. O traço diz "não sei".
    final online =
        status == _StatusApi.online || status == _StatusApi.demonstracao;
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
          if (compacto)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Modelos no catálogo',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: corStatus,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            textoStatus,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${n(total)} modelos · ${n(tenis)} tênis · ${n(chuteiras)} chuteiras',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    ApiService.modoDemo
                        ? 'Modo demonstração (sem API)'
                        : ApiService.baseUrl,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )
          else
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
                            decoration: BoxDecoration(
                              color: corStatus,
                              shape: BoxShape.circle,
                            ),
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
                    ApiService.modoDemo
                        ? 'Modo demonstração (sem API)'
                        : ApiService.baseUrl,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
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
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: context.textMuted,
              ),
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
            Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: context.textMuted,
            ),
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
            OutlinedButton(
              onPressed: aoCadastrar,
              child: const Text('Cadastrar modelo'),
            ),
          ],
        ),
      ),
    );
  }
}
