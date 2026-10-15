import 'package:flutter/material.dart';
import '../main.dart';
import '../models/dashboard.dart';
import '../services/api_service.dart';
import '../services/sessao.dart';
import '../theme/app_theme.dart';
import '../widgets/contato_loja.dart';
import '../widgets/logo_loja.dart';
import '../widgets/pilula.dart';
import 'catalogo_page.dart';
import 'detalhe_page.dart';
import 'login_page.dart';

const _diasSemana = [
  'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira',
  'Sexta-feira', 'Sábado', 'Domingo',
];
const _meses = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

/// Tela inicial depois do login: visão geral da loja e atalho para o provador.
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
      ..showSnackBar(SnackBar(content: Text(mensagem), duration: const Duration(seconds: 2)));
  }

  Future<void> _abrirCatalogo() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CatalogoPage()));
    // O catálogo pode ter mudado estoque ou cadastros: atualiza os números.
    if (mounted) _carregar(silencioso: true);
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

  void _sair() {
    Sessao.instance.encerrar();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final usuario = Sessao.instance.usuario;

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
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'Atualizar painel',
            onPressed: _carregando ? null : () => _carregar(),
          ),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 21),
            tooltip: isDark ? 'Usar tema claro' : 'Usar tema escuro',
            onPressed: () {
              MyApp.themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Conta',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius)),
            onSelected: (valor) {
              if (valor == 'sair') _sair();
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      usuario?.nome ?? 'Usuário',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textStrong,
                      ),
                    ),
                    Text(
                      usuario?.email ?? '',
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'sair',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Sair'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.brand,
                child: Text(
                  usuario?.iniciais ?? '?',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
      return _EstadoErro(mensagem: _erro!, aoTentar: () => _carregar());
    }

    final d = _dados!;
    final r = d.resumo;

    final maiorVenda = d.maisVendidos.fold<int>(1, (m, i) => i.vendas > m ? i.vendas : m);
    final maiorEstoqueAlto = d.estoqueAlto.fold<int>(1, (m, i) => i.estoque > m ? i.estoque : m);

    return RefreshIndicator(
      onRefresh: () => _carregar(silencioso: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          _Cabecalho(nome: Sessao.instance.usuario?.primeiroNome ?? ''),
          const SizedBox(height: 18),
          _CartaoProvador(onTap: _abrirCatalogo),
          const SizedBox(height: 14),
          _GradeKpis(resumo: r),
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
                  proporcao: r.limiteEstoqueBaixo == 0 ? 0 : item.estoque / r.limiteEstoqueBaixo,
                  cor: AppColors.hazard,
                  rotulo: item.estoque == 0 ? 'Esgotado' : 'Acabando',
                  onTap: () => _abrirModelo(item.id),
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
    final data = '${_diasSemana[hoje.weekday - 1]}, ${hoje.day} de ${_meses[hoje.month - 1]}';

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
            Text(data, style: TextStyle(fontSize: 13.5, color: context.textMuted)),
            if (ApiService.modoDemo) const Pilula(texto: 'Dados de demonstração', destaque: true),
          ],
        ),
      ],
    );
  }
}

/// Atalho principal: leva ao catálogo, de onde se calcula o tamanho.
class _CartaoProvador extends StatelessWidget {
  final VoidCallback onTap;
  const _CartaoProvador({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brand,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      clipBehavior: Clip.antiAlias,
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
                child: const Icon(Icons.straighten_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Controle De Estoque ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Escolha o modelo e calcule o tamanho ideal para o cliente.',
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
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
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

  const _Kpi({required this.icone, required this.rotulo, required this.valor, this.cor});

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
          Text(rotulo, style: TextStyle(fontSize: 12, color: context.textMuted)),
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
                        style: TextStyle(fontSize: 12.5, color: context.textMuted),
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
                      style: TextStyle(fontSize: 13.5, color: context.textMuted),
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
            Expanded(child: _NomeEBarra(item: item, proporcao: proporcao, cor: context.accent)),
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
                Text('vendas', style: TextStyle(fontSize: 11.5, color: context.textMuted)),
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

  const _LinhaEstoque({
    required this.item,
    required this.proporcao,
    required this.cor,
    required this.rotulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Expanded(child: _NomeEBarra(item: item, proporcao: proporcao, cor: cor)),
            const SizedBox(width: 14),
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

  const _NomeEBarra({required this.item, required this.proporcao, required this.cor});

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
        Text(item.marca, style: TextStyle(fontSize: 12, color: context.textMuted)),
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
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: cor),
      ),
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
              'Não foi possível carregar o painel',
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