import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models/dashboard.dart';
import '../models/saida_estoque.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import '../services/sessao.dart';
import '../theme/app_theme.dart';
import '../widgets/contato_loja.dart';
import '../widgets/estados.dart';
import '../widgets/logo_loja.dart';
import '../widgets/pilula.dart';
import 'cadastro_page.dart';
import 'catalogo_page.dart';
import 'detalhe_page.dart';

const _diasSemana = [
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
  'Domingo',
];
const _meses = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// Tela inicial depois do login: visão geral da loja e atalhos para o catálogo e provador.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Dashboard? _dados;
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _carregando = true);
    try {
      final dados = await ApiService.instance.dashboard();
      if (!mounted) return;
      setState(() {
        _dados = dados;
        _erro = null;
        _carregando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // Já havia dados na tela: mantém e só avisa. Sem dados: mostra o erro.
      setState(() {
        _carregando = false;
        if (_dados == null) _erro = e.mensagem;
      });
      if (_dados != null) _avisar(e.mensagem);
    }
  }

  void _avisar(String mensagem) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(mensagem), duration: const Duration(seconds: 2)),
      );
  }

  Future<void> _abrirCatalogo() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CatalogoPage()));
    // O catálogo pode ter mudado estoque ou cadastros: atualiza os números.
    if (mounted) _carregar(silencioso: true);
  }

  Future<void> _abrirNovoCadastro() async {
    final resultado = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const CadastroPage()));
    if (!mounted) return;
    if (resultado != null) _avisar(resultado);
    _carregar(silencioso: true);
  }

  /// Toque em um item das listas: busca o modelo completo e abre o detalhe.
  Future<void> _abrirModelo(int id) async {
    try {
      final calcado = await ApiService.instance.buscar(id);
      if (!mounted) return;
      final resultado = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => DetalhePage(calcado: calcado)),
      );
      if (!mounted) return;
      if (resultado != null) _avisar(resultado);
      _carregar(silencioso: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _avisar(e.mensagem);
    }
  }

  Future<void> _reporRapido(ItemDashboard item) async {
    try {
      final calcado = await ApiService.instance.buscar(item.id);
      final atualizado = await ApiService.instance.atualizar(
        calcado.copyWith(estoque: calcado.estoque + 5),
      );
      if (!mounted) return;
      _avisar(
        'Reposição concluída: ${atualizado.nome} agora tem ${atualizado.estoque} un.',
      );
      _carregar(silencioso: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _avisar(e.mensagem);
    }
  }

  Future<void> _copiarRelatorio() async {
    final d = _dados;
    if (d == null) return;
    final r = d.resumo;
    final buffer = StringBuffer()
      ..writeln('📊 *Resumo LandView Stock*')
      ..writeln('• Modelos ativos: ${r.totalModelos}')
      ..writeln('• Unidades em estoque: ${r.unidadesEmEstoque}')
      ..writeln('• Vendas (30 dias): ${r.vendas30Dias}')
      ..writeln('• Modelos acabando/esgotados: ${r.modelosAcabando}');
    if (d.estoqueBaixo.isNotEmpty) {
      buffer.writeln('\n⚠️ *Atenção para reposição:*');
      for (final item in d.estoqueBaixo) {
        buffer.writeln('- ${item.nome} (${item.marca}): ${item.estoque} un.');
      }
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (!mounted) return;
    _avisar('Resumo do painel copiado para a área de transferência!');
  }

  Future<void> _abrirHistoricoSaidas() async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModalHistoricoSaidas(
        aoAbrirModelo: (id) {
          Navigator.of(ctx).pop();
          _abrirModelo(id);
        },
      ),
    );
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
            const LogoLoja(tamanho: 40),
            const SizedBox(width: 12),
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
                  'Painel da loja',
                  style: TextStyle(fontSize: 12, color: context.textMuted),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 21),
            tooltip: 'Histórico de saídas de estoque',
            onPressed: _abrirHistoricoSaidas,
          ),
          if (_dados != null)
            IconButton(
              icon: const Icon(Icons.content_copy_rounded, size: 20),
              tooltip: 'Copiar resumo do painel',
              onPressed: _copiarRelatorio,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'Atualizar painel',
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
          child: _corpo(),
        ),
      ),
    );
  }

  Widget _corpo() {
    if (_carregando && _dados == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null && _dados == null) {
      return EstadoErro(
        titulo: 'Não foi possível carregar o painel',
        mensagem: _erro!,
        aoTentar: () => _carregar(),
      );
    }

    final d = _dados!;
    final r = d.resumo;

    final maiorVenda = d.maisVendidos.fold<int>(
      1,
      (m, i) => i.vendas > m ? i.vendas : m,
    );
    final maiorEstoqueAlto = d.estoqueAlto.fold<int>(
      1,
      (m, i) => i.estoque > m ? i.estoque : m,
    );

    return RefreshIndicator(
      onRefresh: () => _carregar(silencioso: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          ValueListenableBuilder<Usuario?>(
            valueListenable: Sessao.instance.usuarioNotifier,
            builder: (_, u, __) => _Cabecalho(
              nome: (u ?? Sessao.instance.usuario)?.primeiroNome ?? '',
            ),
          ),
          const SizedBox(height: 18),
          _CartaoProvador(
            onTap: _abrirCatalogo,
            onNovoModelo: _abrirNovoCadastro,
          ),
          const SizedBox(height: 14),
          _GradeKpis(resumo: r),
          if (d.menorEstoque != null || d.maiorEstoque != null) ...[
            const SizedBox(height: 14),
            _DestaquesApiDashboard(
              menor: d.menorEstoque,
              maior: d.maiorEstoque,
              aoTocarModelo: _abrirModelo,
            ),
          ],
          const SizedBox(height: 22),
          _Secao(
            titulo: 'Mais vendidos',
            subtitulo: 'Últimos 30 dias',
            vazio: 'Ainda não há vendas registradas no período.',
            iconeVazio: Icons.trending_up_rounded,
            linhas: [
              for (var i = 0; i < d.maisVendidos.length; i++)
                _LinhaRanking(
                  posicao: i + 1,
                  item: d.maisVendidos[i],
                  proporcao: d.maisVendidos[i].vendas / maiorVenda,
                  onTap: () => _abrirModelo(d.maisVendidos[i].id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _Secao(
            titulo: 'Estoque acabando',
            subtitulo: 'Até ${r.limiteEstoqueBaixo} unidades',
            selo: r.modelosAcabando > 0
                ? _Selo(texto: '${r.modelosAcabando}', cor: AppColors.hazard)
                : null,
            vazio: 'Nenhum modelo com estoque baixo.',
            iconeVazio: Icons.check_circle_outline_rounded,
            linhas: [
              for (final item in d.estoqueBaixo)
                _LinhaEstoque(
                  item: item,
                  proporcao: r.limiteEstoqueBaixo == 0
                      ? 0
                      : item.estoque / r.limiteEstoqueBaixo,
                  cor: AppColors.hazard,
                  rotulo: item.estoque == 0 ? 'Esgotado' : 'Acabando',
                  onTap: () => _abrirModelo(item.id),
                  onRepor: () => _reporRapido(item),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _Secao(
            titulo: 'Estoque em excesso',
            subtitulo: '${r.limiteEstoqueAlto} unidades ou mais',
            selo: r.modelosComExcesso > 0
                ? _Selo(texto: '${r.modelosComExcesso}', cor: context.info)
                : null,
            vazio: 'Nenhum modelo com estoque acima do limite.',
            iconeVazio: Icons.check_circle_outline_rounded,
            linhas: [
              for (final item in d.estoqueAlto)
                _LinhaEstoque(
                  item: item,
                  proporcao: item.estoque / maiorEstoqueAlto,
                  cor: context.info,
                  rotulo: 'Excesso',
                  onTap: () => _abrirModelo(item.id),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const RodapeContato(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- cabeçalho

class _Cabecalho extends StatelessWidget {
  final String nome;
  const _Cabecalho({required this.nome});

  String get _saudacao {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Bom dia';
    if (hora < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    final data =
        '${_diasSemana[hoje.weekday - 1]}, ${hoje.day} de ${_meses[hoje.month - 1]}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nome.isEmpty ? _saudacao : '$_saudacao, $nome',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
            color: context.textStrong,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              data,
              style: TextStyle(fontSize: 13.5, color: context.textMuted),
            ),
            if (ApiService.modoDemo)
              const Pilula(texto: 'Dados de demonstração', destaque: true),
          ],
        ),
      ],
    );
  }
}

/// Atalho principal: leva ao catálogo e provador, com botão rápido de cadastro.
class _CartaoProvador extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onNovoModelo;
  const _CartaoProvador({required this.onTap, required this.onNovoModelo});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.straighten_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Catálogo & Provador Virtual',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Consulte o estoque, registre vendas e calcule o tamanho ideal para o cliente.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
          Material(
            color: Colors.black.withValues(alpha: 0.12),
            child: InkWell(
              onTap: onNovoModelo,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Cadastrar novo modelo no catálogo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------- KPIs

class _GradeKpis extends StatelessWidget {
  final ResumoDashboard resumo;
  const _GradeKpis({required this.resumo});

  @override
  Widget build(BuildContext context) {
    final alertas = resumo.modelosAcabando + resumo.modelosComExcesso;

    final kpis = [
      _Kpi(
        icone: Icons.inventory_2_outlined,
        rotulo: 'Modelos',
        valor: '${resumo.totalModelos}',
      ),
      _Kpi(
        icone: Icons.layers_outlined,
        rotulo: 'Unidades em estoque',
        valor: '${resumo.unidadesEmEstoque}',
      ),
      _Kpi(
        icone: Icons.trending_up_rounded,
        rotulo: 'Vendas em 30 dias',
        valor: '${resumo.vendas30Dias}',
      ),
      _Kpi(
        icone: Icons.warning_amber_rounded,
        rotulo: 'Alertas de estoque',
        valor: '$alertas',
        cor: alertas > 0 ? AppColors.hazard : null,
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final colunas = c.maxWidth >= 600 ? 4 : 2;
        const espaco = 10.0;
        final largura = (c.maxWidth - espaco * (colunas - 1)) / colunas;
        return Wrap(
          spacing: espaco,
          runSpacing: espaco,
          children: [for (final k in kpis) SizedBox(width: largura, child: k)],
        );
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final String valor;
  final Color? cor;

  const _Kpi({
    required this.icone,
    required this.rotulo,
    required this.valor,
    this.cor,
  });

  @override
  Widget build(BuildContext context) {
    final destaque = cor ?? context.accent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: destaque.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icone, size: 18, color: destaque),
          ),
          const SizedBox(height: 12),
          Text(
            valor,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              color: context.textStrong,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            rotulo,
            style: TextStyle(fontSize: 12, color: context.textMuted),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ seções

class _Secao extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Widget? selo;
  final String vazio;
  final IconData iconeVazio;
  final List<Widget> linhas;

  const _Secao({
    required this.titulo,
    required this.subtitulo,
    required this.vazio,
    required this.iconeVazio,
    required this.linhas,
    this.selo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: context.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: context.textStrong,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitulo,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selo != null) selo!,
              ],
            ),
          ),
          if (linhas.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
              child: Row(
                children: [
                  Icon(iconeVazio, size: 20, color: context.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      vazio,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: context.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < linhas.length; i++) ...[
              Divider(color: context.hairline),
              linhas[i],
            ],
        ],
      ),
    );
  }
}

class _LinhaRanking extends StatelessWidget {
  final int posicao;
  final ItemDashboard item;
  final double proporcao;
  final VoidCallback onTap;

  const _LinhaRanking({
    required this.posicao,
    required this.item,
    required this.proporcao,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primeiro = posicao == 1;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primeiro ? AppColors.brand : Colors.transparent,
                shape: BoxShape.circle,
                border: primeiro ? null : Border.all(color: context.hairline),
              ),
              child: Text(
                '$posicao',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: primeiro ? Colors.white : context.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _NomeEBarra(
                item: item,
                proporcao: proporcao,
                cor: context.accent,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.vendas}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: context.textStrong,
                  ),
                ),
                Text(
                  'vendas',
                  style: TextStyle(fontSize: 11.5, color: context.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LinhaEstoque extends StatelessWidget {
  final ItemDashboard item;
  final double proporcao;
  final Color cor;
  final String rotulo;
  final VoidCallback onTap;
  final VoidCallback? onRepor;

  const _LinhaEstoque({
    required this.item,
    required this.proporcao,
    required this.cor,
    required this.rotulo,
    required this.onTap,
    this.onRepor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: _NomeEBarra(item: item, proporcao: proporcao, cor: cor),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.estoque} un.',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: context.textStrong,
                  ),
                ),
                const SizedBox(height: 4),
                _Selo(texto: rotulo, cor: cor),
              ],
            ),
            if (onRepor != null) ...[
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onRepor,
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text('+5 un.'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 34),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NomeEBarra extends StatelessWidget {
  final ItemDashboard item;
  final double proporcao;
  final Color cor;

  const _NomeEBarra({
    required this.item,
    required this.proporcao,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.nome,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: context.textStrong,
          ),
        ),
        Text(
          item.marca,
          style: TextStyle(fontSize: 12, color: context.textMuted),
        ),
        const SizedBox(height: 8),
        _Barra(valor: proporcao, cor: cor),
      ],
    );
  }
}

/// Barra proporcional desenhada à mão (sem pacote de gráficos), com animação.
class _Barra extends StatelessWidget {
  final double valor;
  final Color cor;

  const _Barra({required this.valor, required this.cor});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(
        children: [
          Container(height: 6, color: context.hairline),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: valor.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: v,
              child: Container(height: 6, color: cor),
            ),
          ),
        ],
      ),
    );
  }
}

class _Selo extends StatelessWidget {
  final String texto;
  final Color cor;

  const _Selo({required this.texto, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: cor,
        ),
      ),
    );
  }
}

/// Destaques de menor e maior estoque vindos da rota GET /dashboard/ do backend.
class _DestaquesApiDashboard extends StatelessWidget {
  final ExtremoEstoque? menor;
  final ExtremoEstoque? maior;
  final void Function(int id) aoTocarModelo;

  const _DestaquesApiDashboard({
    this.menor,
    this.maior,
    required this.aoTocarModelo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 18, color: context.accent),
              const SizedBox(width: 8),
              Text(
                'Destaques de estoque (API)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.textMuted,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (menor != null)
                Expanded(
                  child: InkWell(
                    onTap: () => aoTocarModelo(menor!.produtoId),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Menor estoque',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.danger,
                                ),
                              ),
                              Icon(
                                Icons.arrow_downward_rounded,
                                size: 15,
                                color: AppColors.danger,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            menor!.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.textStrong,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${menor!.quantidade} un. disponíveis',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (menor != null && maior != null) const SizedBox(width: 10),
              if (maior != null)
                Expanded(
                  child: InkWell(
                    onTap: () => aoTocarModelo(maior!.produtoId),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.info.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(
                          color: context.info.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Maior estoque',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: context.info,
                                ),
                              ),
                              Icon(
                                Icons.arrow_upward_rounded,
                                size: 15,
                                color: context.info,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            maior!.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.textStrong,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${maior!.quantidade} un. disponíveis',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Modal que lista as movimentações de saída de estoque da rota GET /stock-exit/.
class _ModalHistoricoSaidas extends StatefulWidget {
  final void Function(int id) aoAbrirModelo;

  const _ModalHistoricoSaidas({required this.aoAbrirModelo});

  @override
  State<_ModalHistoricoSaidas> createState() => _ModalHistoricoSaidasState();
}

class _ModalHistoricoSaidasState extends State<_ModalHistoricoSaidas> {
  bool _carregando = true;
  String? _erro;
  List<SaidaEstoque> _saidas = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final lista = await ApiService.instance.listarSaidas(page: 1, pageSize: 30);
      if (!mounted) return;
      setState(() {
        _saidas = lista;
        _carregando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.mensagem;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível obter o histórico de saídas.';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.hairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Histórico de Saídas de Estoque',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: context.textStrong,
                        ),
                      ),
                      Text(
                        'Auditoria de saídas e baixas registradas na API',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Recarregar histórico',
                  onPressed: _carregando ? null : _carregar,
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(color: context.hairline, height: 1),
          Expanded(
            child: _conteudo(context),
          ),
        ],
      ),
    );
  }

  Widget _conteudo(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 36, color: AppColors.danger),
              const SizedBox(height: 10),
              Text(
                _erro!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: context.textMuted),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _carregar,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    if (_saidas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_outlined, size: 36, color: context.textMuted),
              const SizedBox(height: 10),
              Text(
                'Nenhuma saída de estoque registrada ainda.',
                style: TextStyle(fontSize: 14, color: context.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _saidas.length,
      separatorBuilder: (_, __) => Divider(color: context.hairline, height: 1),
      itemBuilder: (context, i) {
        final s = _saidas[i];
        final nome = s.nomeProduto ?? 'Produto #${s.idProduto}';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.output_rounded,
              size: 20,
              color: AppColors.danger,
            ),
          ),
          title: Text(
            nome,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.textStrong,
            ),
          ),
          subtitle: Text(
            'Registro #${s.id} · Estoque #${s.idEstoque} · Usuário #${s.idUsuario}',
            style: TextStyle(fontSize: 11.5, color: context.textMuted),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '-${s.quantidade} un.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ),
          onTap: () => widget.aoAbrirModelo(s.idProduto),
        );
      },
    );
  }
}
