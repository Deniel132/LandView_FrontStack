// Importa os componentes gráficos do Material Design do Flutter
import 'package:flutter/material.dart';
// Importa o modelo de usuário para verificar permissões do cargo na Navbar
import '../models/usuario.dart';
// Importa o gerenciador da sessão ativa para reagir a mudanças de usuário
import '../services/sessao.dart';
// Importa o tema, cores institucionais e extensões visuais
import '../theme/app_theme.dart';
// Importa o logotipo da marca e o menu suspenso da conta do colaborador
import '../widgets/logo_loja.dart';
// Importa a tela de listagem e gestão do catálogo de calçados
import 'catalogo_page.dart';
// Importa a tela de indicadores e visão gerencial da loja
import 'dashboard_page.dart';
// Importa a tela do Provador Virtual com suporte a seletor de modelos
import 'recomendacao_page.dart';
// Importa a tela de auditoria do histórico de saídas de estoque
import 'saidas_page.dart';

/// Estrutura descritiva de cada destino exibido na barra de navegação principal.
class _DestinoNav {
  // Rótulo curto exibido no botão da Navbar
  final String rotulo;
  // Subtítulo contextual mostrado abaixo do título principal em telas móveis
  final String subtitulo;
  // Ícone exibido quando a aba está inativa
  final IconData icone;
  // Ícone destacado exibido quando a aba está selecionada
  final IconData iconeAtivo;

  const _DestinoNav({
    required this.rotulo,
    required this.subtitulo,
    required this.icone,
    required this.iconeAtivo,
  });
}

/// Shell principal de navegação responsiva (Navbar) após o login.
/// Exibe abas claras para Painel, Catálogo, Provador e Saídas (exclusiva do Proprietário):
/// - Em telas largas (>= 840px): Navbar horizontal integrada na barra superior (Web/Desktop).
/// - Em celulares e telas compactas (< 840px): NavigationBar fixa no rodapé (Mobile Android/iOS).
class NavegacaoPage extends StatefulWidget {
  /// Índice inicial da aba selecionada (útil para testes e atalhos diretos)
  final int indiceInicial;

  // Construtor constante com aba inicial padrão no Painel (0)
  const NavegacaoPage({super.key, this.indiceInicial = 0});

  @override
  State<NavegacaoPage> createState() => _NavegacaoPageState();
}

class _NavegacaoPageState extends State<NavegacaoPage> {
  // Índice da aba atualmente ativa na Navbar
  late int _indiceAtual;

  // Notificadores individuais que disparam recarregamento silencioso em cada aba
  final _gatilhoPainel = ValueNotifier<int>(0);
  final _gatilhoCatalogo = ValueNotifier<int>(0);
  final _gatilhoProvador = ValueNotifier<int>(0);
  final _gatilhoSaidas = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    // Define a aba inicial selecionada
    _indiceAtual = widget.indiceInicial;
  }

  @override
  void dispose() {
    // Libera os notificadores da memória ao descartar a shell
    _gatilhoPainel.dispose();
    _gatilhoCatalogo.dispose();
    _gatilhoProvador.dispose();
    _gatilhoSaidas.dispose();
    super.dispose();
  }

  /// Alterna para a aba informada e atualiza seus dados caso necessário
  void _selecionarAba(int novoIndice, {required bool incluirSaidas}) {
    // Impede índices inválidos caso as permissões tenham mudado
    final maxIndice = incluirSaidas ? 3 : 2;
    final destino = novoIndice.clamp(0, maxIndice);
    // Atualiza a interface apenas se a aba mudou
    if (_indiceAtual != destino) {
      setState(() => _indiceAtual = destino);
    }
    // Dispara atualização silenciosa na aba selecionada para refletir vendas/estoque recentes
    _notificarAba(destino);
  }

  /// Dispara o gatilho de recarregamento para uma aba específica
  void _notificarAba(int indice) {
    switch (indice) {
      case 0:
        _gatilhoPainel.value++;
      case 1:
        _gatilhoCatalogo.value++;
      case 2:
        _gatilhoProvador.value++;
      case 3:
        _gatilhoSaidas.value++;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Largura atual da janela ou tela do dispositivo
    final largura = MediaQuery.sizeOf(context).width;
    // Usa Navbar horizontal superior em desktops (>= 840px) e inferior fixa em celulares/tablets
    final navbarTopo = largura >= 840;
    // Compacta botões auxiliares em telas estreitas de celular
    final telaEstreita = largura < 430;

    // Ouve mudanças no usuário logado para exibir ou ocultar a aba Saídas conforme o cargo
    return ValueListenableBuilder<Usuario?>(
      valueListenable: Sessao.instance.usuarioNotifier,
      builder: (context, usuarioNotificado, _) {
        // Recupera o usuário ativo na sessão
        final usuario = usuarioNotificado ?? Sessao.instance.usuario;
        // Somente o Proprietário enxerga a aba de auditoria de saídas na Navbar
        final podeVerSaidas = usuario?.podeVerAuditoria ?? false;

        // Lista de destinos da barra de navegação
        final destinos = <_DestinoNav>[
          const _DestinoNav(
            rotulo: 'Painel',
            subtitulo: 'Painel da loja',
            icone: Icons.dashboard_outlined,
            iconeAtivo: Icons.dashboard_rounded,
          ),
          const _DestinoNav(
            rotulo: 'Catálogo',
            subtitulo: 'Catálogo & Estoque',
            icone: Icons.inventory_2_outlined,
            iconeAtivo: Icons.inventory_2_rounded,
          ),
          const _DestinoNav(
            rotulo: 'Provador',
            subtitulo: 'Provador Virtual',
            icone: Icons.straighten_outlined,
            iconeAtivo: Icons.straighten_rounded,
          ),
          if (podeVerSaidas)
            const _DestinoNav(
              rotulo: 'Saídas',
              subtitulo: 'Auditoria de saídas',
              icone: Icons.history_outlined,
              iconeAtivo: Icons.history_rounded,
            ),
        ];

        // Garante que o índice atual não ultrapasse a quantidade visível de abas
        final indiceSeguro = _indiceAtual.clamp(0, destinos.length - 1);
        final destinoAtual = destinos[indiceSeguro];

        // Mantém o estado das abas em memória usando IndexedStack
        final telas = <Widget>[
          DashboardPage(
            mostrarAppBar: false,
            gatilhoAtualizacao: _gatilhoPainel,
            // Ao tocar no card azul "Catálogo & Provador Virtual", muda direto para a aba Catálogo
            aoAbrirCatalogo: () =>
                _selecionarAba(1, incluirSaidas: podeVerSaidas),
          ),
          CatalogoPage(
            mostrarAppBar: false,
            gatilhoAtualizacao: _gatilhoCatalogo,
          ),
          RecomendacaoPage(
            mostrarAppBar: false,
            gatilhoAtualizacao: _gatilhoProvador,
          ),
          if (podeVerSaidas) SaidasPage(gatilhoAtualizacao: _gatilhoSaidas),
        ];

        return Scaffold(
          appBar: AppBar(
            // Altura padronizada da barra superior
            toolbarHeight: 68,
            // Reduz espaçamento lateral em telas estreitas de celular
            titleSpacing: telaEstreita ? 12 : 20,
            title: Row(
              children: [
                // Logotipo circular oficial da LandView
                LogoLoja(tamanho: telaEstreita ? 34 : 38),
                SizedBox(width: telaEstreita ? 9 : 12),
                // Nome do aplicativo e subtítulo contextual em telas compactas
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'LandView Stock',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: telaEstreita ? 15 : 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: context.textStrong,
                        ),
                      ),
                      if (!navbarTopo)
                        Text(
                          destinoAtual.subtitulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: telaEstreita ? 11.5 : 12,
                            color: context.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                // Em desktop/web largo, exibe a Navbar horizontal integrada ao lado do título
                if (navbarTopo) ...[
                  const SizedBox(width: 24),
                  Flexible(
                    flex: 3,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < destinos.length; i++) ...[
                            _ItemNavbarTopo(
                              destino: destinos[i],
                              selecionado: i == indiceSeguro,
                              aoTocar: () => _selecionarAba(
                                i,
                                incluirSaidas: podeVerSaidas,
                              ),
                            ),
                            if (i < destinos.length - 1)
                              const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              // Botão para atualizar manualmente os dados da aba atualmente aberta
              IconButton(
                visualDensity: telaEstreita ? VisualDensity.compact : null,
                padding: EdgeInsets.symmetric(horizontal: telaEstreita ? 6 : 8),
                constraints: telaEstreita
                    ? const BoxConstraints(minWidth: 34, minHeight: 34)
                    : null,
                icon: const Icon(Icons.refresh_rounded, size: 22),
                tooltip: 'Atualizar ${destinoAtual.rotulo.toLowerCase()}',
                onPressed: () => _notificarAba(indiceSeguro),
              ),
              // Botão reutilizável de alternância entre tema claro e tema escuro
              BotaoAlternarTema(compacto: telaEstreita),
              // Avatar do usuário com menu suspenso da conta (e "Criar nova conta" para o e-mail mãe)
              const MarcaAppBar(),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: context.hairline, height: 1),
            ),
          ),
          // Mantém as telas das abas em memória preservando filtros e rolagens
          body: IndexedStack(
            index: indiceSeguro,
            children: telas,
          ),
          // Em celulares e janelas menores (< 840px), exibe a Navbar fixa na parte inferior
          bottomNavigationBar: navbarTopo
              ? null
              : Container(
                  decoration: BoxDecoration(
                    color: context.cardSurface,
                    border: Border(top: BorderSide(color: context.hairline)),
                  ),
                  child: NavigationBar(
                    height: 66,
                    elevation: 0,
                    backgroundColor: context.cardSurface,
                    surfaceTintColor: Colors.transparent,
                    indicatorColor: context.accent.withValues(alpha: 0.14),
                    selectedIndex: indiceSeguro,
                    onDestinationSelected: (i) =>
                        _selecionarAba(i, incluirSaidas: podeVerSaidas),
                    destinations: [
                      for (final d in destinos)
                        NavigationDestination(
                          icon: Icon(d.icone, color: context.textMuted),
                          selectedIcon: Icon(
                            d.iconeAtivo,
                            color: context.accent,
                          ),
                          label: d.rotulo,
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

/// Botão individual de aba exibido na Navbar horizontal em telas de computador e web larga.
class _ItemNavbarTopo extends StatelessWidget {
  // Dados do destino (rótulo e ícones)
  final _DestinoNav destino;

  // Indica se esta aba é a selecionada atualmente
  final bool selecionado;

  // Ação disparada ao clicar na aba
  final VoidCallback aoTocar;

  const _ItemNavbarTopo({
    required this.destino,
    required this.selecionado,
    required this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    // Cor de destaque azul quando ativo ou cinza discreto quando inativo
    final corTexto = selecionado ? context.accent : context.textMuted;

    return Material(
      color: selecionado
          ? context.accent.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: selecionado
                ? Border.all(color: context.accent.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícone da seção selecionada ou inativa
              Icon(
                selecionado ? destino.iconeAtivo : destino.icone,
                size: 18,
                color: corTexto,
              ),
              const SizedBox(width: 7),
              // Rótulo da seção
              Text(
                destino.rotulo,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selecionado ? FontWeight.w700 : FontWeight.w600,
                  color: corTexto,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

