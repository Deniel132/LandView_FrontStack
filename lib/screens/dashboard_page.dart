// Pacote de componentes visuais do Flutter baseados no Material Design.
import 'package:flutter/material.dart';
// Serviços de plataforma do Flutter (usado para copiar texto para a área de transferência do sistema).
import 'package:flutter/services.dart';
// Modelo de dados que encapsula todos os dados agregados do painel da loja.
import '../models/dashboard.dart';
// Modelo de dados que representa o registro de auditoria de saída de estoque.
import '../models/saida_estoque.dart';
// Modelo do usuário autenticado no sistema.
import '../models/usuario.dart';
// Serviço singleton responsável por todas as requisições HTTP e regras de negócio com a API.
import '../services/api_service.dart';
// Gerenciador singleton da sessão local do usuário e token de autenticação.
import '../services/sessao.dart';
// Definições de cores da identidade visual e extensões de contexto para tema claro e escuro.
import '../theme/app_theme.dart';
// Widget reutilizável que exibe as informações de contato e rodapé da loja.
import '../widgets/contato_loja.dart';
// Widgets reutilizáveis para exibir telas de carregamento, estados de erro e listas vazias.
import '../widgets/estados.dart';
// Widget que renderiza o logo circular estilizado da LandView.
import '../widgets/logo_loja.dart';
// Tela de cadastro de novos modelos de calçados.
import 'cadastro_page.dart';
// Tela de listagem e catálogo completo de calçados.
import 'catalogo_page.dart';
// Tela com informações detalhadas e ações de um calçado específico.
import 'detalhe_page.dart';
// Tela e componente compartilhado de auditoria de saídas de estoque.
import 'saidas_page.dart';

/// Lista com os nomes dos dias da semana em português para formatação da data no cabeçalho.
const _diasSemana = [
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
  'Domingo',
];

/// Lista com os nomes dos meses do ano em português para exibição por extenso.
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

/// Tela inicial após o login do usuário.
/// Apresenta uma visão executiva dos números da loja (KPIs), modelos mais vendidos,
/// alertas de estoque crítico, atalhos rápidos para o provador/catálogo e histórico de saídas.
class DashboardPage extends StatefulWidget {
  /// Controla se a tela exibe sua própria AppBar superior (falso quando embutida na Navbar principal).
  final bool mostrarAppBar;

  /// Callback opcional acionado ao tocar no cartão de Catálogo dentro da Navbar principal.
  final VoidCallback? aoAbrirCatalogo;

  /// Notificador opcional que dispara atualização silenciosa quando o botão Atualizar da Navbar é pressionado.
  final ValueNotifier<int>? gatilhoAtualizacao;

  // Construtor constante com parâmetros opcionais de integração com a Navbar.
  const DashboardPage({
    super.key,
    this.mostrarAppBar = true,
    this.aoAbrirCatalogo,
    this.gatilhoAtualizacao,
  });

  @override
  // Cria o estado mutável associado a esta página.
  State<DashboardPage> createState() => _DashboardPageState();
}

/// Estado interno do DashboardPage, gerenciando carregamento de dados da API e interações.
class _DashboardPageState extends State<DashboardPage> {
  // Armazena os dados consolidados do dashboard retornados pelo ApiService.
  Dashboard? _dados;
  // Flag que indica se os dados estão sendo requisitados no momento.
  bool _carregando = true;
  // Flag que trava novos cliques enquanto um modelo ou tela está sendo aberta (evita abrir rotas duplicadas).
  bool _abrindoModelo = false;
  // Conjunto de IDs que estão em processo de reposição rápida (+5 un.) para evitar cliques repetidos.
  final Set<int> _repondoIds = {};
  // Mensagem descritiva de erro caso a requisição falhe e não haja dados prévios.
  String? _erro;

  @override
  // Método executado na montagem inicial do widget.
  void initState() {
    // Executa a inicialização padrão da superclasse.
    super.initState();
    // Escuta o gatilho de atualização caso a página esteja embutida na Navbar.
    widget.gatilhoAtualizacao?.addListener(_aoDispararGatilho);
    // Dispara a busca inicial dos dados do painel.
    _carregar();
  }

  @override
  // Atualiza o ouvinte caso o notificador recebido por parâmetro seja trocado.
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Remove o ouvinte do notificador antigo e registra no novo.
    if (oldWidget.gatilhoAtualizacao != widget.gatilhoAtualizacao) {
      oldWidget.gatilhoAtualizacao?.removeListener(_aoDispararGatilho);
      widget.gatilhoAtualizacao?.addListener(_aoDispararGatilho);
    }
  }

  @override
  // Remove o ouvinte ao desmontar o widget para evitar vazamento de memória.
  void dispose() {
    widget.gatilhoAtualizacao?.removeListener(_aoDispararGatilho);
    super.dispose();
  }

  /// Recarrega o painel sempre que a Navbar solicitar atualização.
  void _aoDispararGatilho() {
    // Recarrega com feedback visual apenas se ainda não houver dados, caso contrário silenciosamente.
    _carregar(silencioso: _dados != null);
  }

  /// Busca os dados mais recentes do dashboard a partir do ApiService.
  /// O parâmetro [silencioso] permite recarregar os dados em segundo plano sem piscar o spinner na tela.
  Future<void> _carregar({bool silencioso = false}) async {
    // Se não for carregamento silencioso, ativa o spinner visual de carregando.
    if (!silencioso) setState(() => _carregando = true);
    try {
      // Chama o endpoint integrado da API do Render (com fallback inteligente).
      final dados = await ApiService.instance.dashboard();
      // Se o widget não estiver mais na árvore de renderização, encerra a execução com segurança.
      if (!mounted) return;
      // Atualiza o estado da tela com os dados carregados com sucesso.
      setState(() {
        _dados = dados;
        _erro = null;
        _carregando = false;
      });
    } on ApiException catch (e) {
      // Se o widget foi desmontado durante a espera assíncrona, ignora o retorno.
      if (!mounted) return;
      // Se já existiam dados na tela, mantém os dados visíveis e apenas desliga o carregamento.
      setState(() {
        _carregando = false;
        // Se a tela estava em branco, armazena a mensagem de erro para exibir o estado de erro completo.
        if (_dados == null) _erro = e.mensagem;
      });
      // Se já havia dados em tela, apenas exibe um aviso flutuante (SnackBar) sem quebrar o layout.
      if (_dados != null) _avisar(e.mensagem);
    }
  }

  /// Exibe um aviso temporário (SnackBar) na parte inferior da tela.
  void _avisar(String mensagem) {
    // Obtém o ScaffoldMessenger da árvore para controlar mensagens suspensas.
    ScaffoldMessenger.of(context)
      // Oculta imediatamente qualquer SnackBar anterior que ainda esteja visível.
      ..hideCurrentSnackBar()
      // Apresenta o novo aviso com duração de 2 segundos.
      ..showSnackBar(
        SnackBar(content: Text(mensagem), duration: const Duration(seconds: 2)),
      );
  }

  /// Navega para a tela de catálogo completo e provador virtual.
  Future<void> _abrirCatalogo() async {
    // Quando embutido na Navbar principal, apenas troca para a aba Catálogo em vez de empilhar nova tela.
    if (widget.aoAbrirCatalogo != null) {
      widget.aoAbrirCatalogo!();
      return;
    }
    // Impede abrir múltiplas instâncias do catálogo em cliques rápidos simultâneos.
    if (_abrindoModelo) return;
    // Ativa a trava de navegação durante a abertura do catálogo.
    _abrindoModelo = true;
    try {
      // Empilha a rota da página CatalogoPage na navegação.
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CatalogoPage()));
      // Ao retornar do catálogo, recarrega silenciosamente os dados pois o estoque pode ter mudado.
      if (mounted) _carregar(silencioso: true);
    } finally {
      // Libera a trava de navegação ao retornar ao painel.
      _abrindoModelo = false;
    }
  }

  /// Navega para a tela de cadastro de novo modelo de calçado.
  Future<void> _abrirNovoCadastro() async {
    // Impede abrir múltiplas instâncias da tela de cadastro em cliques rápidos.
    if (_abrindoModelo) return;
    // Ativa a trava de navegação durante a abertura do cadastro.
    _abrindoModelo = true;
    try {
      // Abre a tela de cadastro e aguarda o resultado opcional retornado por ela.
      final resultado = await Navigator.of(
        context,
      ).push<String>(MaterialPageRoute(builder: (_) => const CadastroPage()));
      // Verifica se a tela continua ativa após a navegação.
      if (!mounted) return;
      // Se um texto de sucesso foi retornado pelo cadastro, exibe-o no aviso.
      if (resultado != null) _avisar(resultado);
      // Atualiza os dados do painel para incluir o novo calçado recém-criado.
      _carregar(silencioso: true);
    } finally {
      // Libera a trava de navegação ao retornar ao painel.
      _abrindoModelo = false;
    }
  }

  /// Chamado ao tocar em um calçado nas listas (Mais vendidos, Estoque, Destaques ou Histórico):
  /// bloqueia cliques repetidos, exibe overlay modal de loading durante a busca na API
  /// e garante que apenas uma tela de detalhes seja aberta por vez.
  Future<void> _abrirModelo(int id) async {
    // Se já existe uma abertura ou requisição em andamento, ignora os cliques extras.
    if (_abrindoModelo) return;
    // Ativa imediatamente a trava contra múltiplos cliques.
    _abrindoModelo = true;
    // Flag local que controla se o overlay de carregamento ainda está visível na pilha.
    var loadingAberto = true;

    // Exibe diálogo modal de loading bloqueando novos toques atrás enquanto consulta a API.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: OverlayCarregando()),
      ),
    ).whenComplete(() {
      // Marca o loading como encerrado assim que o diálogo for fechado.
      loadingAberto = false;
    });

    try {
      // Busca o modelo completo (preço, forma, tabela de tamanhos e estoque atualizado).
      final calcado = await ApiService.instance.buscar(id);
      // Confirma que a tela atual ainda está visível.
      if (!mounted) return;
      // Fecha o overlay de loading antes de abrir a tela de detalhes do produto.
      if (loadingAberto) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingAberto = false;
      }
      // Empilha a tela de detalhes passando o objeto Calçado carregado.
      final resultado = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => DetalhePage(calcado: calcado)),
      );
      // Se foi desmontado enquanto o detalhe estava aberto, cancela.
      if (!mounted) return;
      // Exibe mensagem de confirmação caso o usuário tenha registrado venda ou alteração no detalhe.
      if (resultado != null) _avisar(resultado);
      // Atualiza os números do painel para refletir qualquer baixa ou edição realizada.
      _carregar(silencioso: true);
    } on ApiException catch (e) {
      // Fecha o overlay de loading antes de exibir o alerta de erro.
      if (loadingAberto && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingAberto = false;
      }
      // Notifica o usuário caso a busca do calçado falhe na rede.
      if (!mounted) return;
      _avisar(e.mensagem);
    } catch (_) {
      // Fecha o overlay de loading em caso de erro inesperado de rede ou formato.
      if (loadingAberto && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingAberto = false;
      }
      if (!mounted) return;
      _avisar('Não foi possível abrir o produto. Tente novamente.');
    } finally {
      // Garante que o diálogo nunca fique preso em caso de saída antecipada.
      if (loadingAberto && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      // Libera a trava para permitir abrir outro modelo no painel.
      _abrindoModelo = false;
    }
  }

  /// Botão de reposição rápida (+5 unidades) diretamente na linha de estoque baixo.
  Future<void> _reporRapido(ItemDashboard item) async {
    // Impede múltiplos envios da reposição rápida caso o usuário clique várias vezes seguidas.
    if (_repondoIds.contains(item.id) || _abrindoModelo) return;
    // Marca este item como em reposição e atualiza o estado visual do botão.
    setState(() => _repondoIds.add(item.id));
    try {
      // Busca o registro atual completo do calçado.
      final calcado = await ApiService.instance.buscar(item.id);
      // Envia requisição de atualização incrementando 5 unidades no estoque.
      final atualizado = await ApiService.instance.atualizar(
        calcado.copyWith(estoque: calcado.estoque + 5),
      );
      // Verifica se a tela ainda está ativa.
      if (!mounted) return;
      // Notifica o sucesso da reposição com o novo saldo total.
      _avisar(
        'Reposição concluída: ${atualizado.nome} agora tem ${atualizado.estoque} un.',
      );
      // Atualiza os indicadores do dashboard em segundo plano.
      _carregar(silencioso: true);
    } on ApiException catch (e) {
      // Informa qualquer falha ao tentar atualizar o estoque.
      if (!mounted) return;
      _avisar(e.mensagem);
    } finally {
      // Remove o ID da lista de reposição em andamento se a tela ainda estiver montada.
      if (mounted) {
        setState(() => _repondoIds.remove(item.id));
      } else {
        _repondoIds.remove(item.id);
      }
    }
  }

  /// Constrói um resumo textual formatado dos indicadores da loja e copia para a área de transferência.
  Future<void> _copiarRelatorio() async {
    // Recupera os dados atuais do estado.
    final d = _dados;
    // Se ainda não houver dados carregados, não faz nada.
    if (d == null) return;
    // Atalho para o objeto de resumo.
    final r = d.resumo;
    // Construtor de strings eficiente para gerar o relatório em texto puro.
    final buffer = StringBuffer()
      ..writeln('📊 *Resumo LandView Stock*')
      ..writeln('• Modelos ativos: ${r.totalModelos}')
      ..writeln('• Unidades em estoque: ${r.unidadesEmEstoque}')
      ..writeln('• Vendas (30 dias): ${r.vendas30Dias}')
      ..writeln('• Modelos acabando/esgotados: ${r.modelosAcabando}');
    // Se existirem modelos em estoque baixo, adiciona a lista com os alertas.
    if (d.estoqueBaixo.isNotEmpty) {
      buffer.writeln('\n⚠️ *Atenção para reposição:*');
      for (final item in d.estoqueBaixo) {
        buffer.writeln('- ${item.nome} (${item.marca}): ${item.estoque} un.');
      }
    }
    // Salva o texto gerado na área de transferência do sistema operacional.
    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    // Confirma que a tela continua montada.
    if (!mounted) return;
    // Emite o aviso de que o relatório foi copiado.
    _avisar('Resumo do painel copiado para a área de transferência!');
  }

  /// Abre o modal inferior (bottom sheet) com o histórico de auditoria de saídas de estoque da API.
  Future<void> _abrirHistoricoSaidas() async {
    // Exibe o modal inferior do Material Design.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Constrói o corpo do modal passando o callback para navegar para um modelo específico.
      builder: (ctx) => _ModalHistoricoSaidas(
        aoAbrirModelo: (id) {
          // Fecha o modal antes de empilhar a tela do modelo.
          Navigator.of(ctx).pop();
          _abrirModelo(id);
        },
      ),
    );
  }

  @override
  // Constrói a estrutura visual principal da tela.
  Widget build(BuildContext context) {
    // Centraliza o conteúdo e impõe largura máxima para visual agradável em telas grandes e navegadores web.
    final conteudoCentral = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: _corpo(),
      ),
    );

    // Quando embutida na Navbar principal, retorna apenas o conteúdo central sem AppBar duplicada.
    if (!widget.mostrarAppBar) return conteudoCentral;

    // Detecta telas estreitas de celular para compactar espaçamentos da AppBar sem sobrepor textos.
    final telaEstreita = MediaQuery.sizeOf(context).width < 430;

    return Scaffold(
      appBar: AppBar(
        // Altura personalizada da barra de navegação superior.
        toolbarHeight: 68,
        // Espaçamento horizontal reduzido em celulares para dar mais área útil ao título.
        titleSpacing: telaEstreita ? 12 : 20,
        title: Row(
          children: [
            // Logo circular oficial da marca LandView dimensionado conforme a largura da tela.
            LogoLoja(tamanho: telaEstreita ? 34 : 40),
            // Espaçamento horizontal proporcional entre o logo e o título.
            SizedBox(width: telaEstreita ? 9 : 12),
            // Flexible impede que o texto do título invada os ícones de ação em telas pequenas de celular.
            Flexible(
              // Empilha o título principal e o subtítulo verticalmente.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nome principal do sistema com truncamento seguro em uma única linha.
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
                  // Subtítulo descritivo do painel com truncamento seguro.
                  Text(
                    'Painel da loja',
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
          ],
        ),
        actions: [
          // Botão para abrir o histórico de saídas de estoque (auditoria GET /stock-exit/ exclusiva do Proprietário).
          if (Sessao.instance.usuario?.podeVerAuditoria ?? false)
            IconButton(
              // Reduz a densidade visual em telas estreitas de celular.
              visualDensity: telaEstreita ? VisualDensity.compact : null,
              // Ajusta o preenchimento horizontal para economizar espaço na AppBar.
              padding: EdgeInsets.symmetric(horizontal: telaEstreita ? 6 : 8),
              // Define área mínima compacta em celulares.
              constraints: telaEstreita
                  ? const BoxConstraints(minWidth: 34, minHeight: 34)
                  : null,
              icon: const Icon(Icons.history_rounded, size: 21),
              tooltip: 'Histórico de saídas de estoque',
              onPressed: _abrirHistoricoSaidas,
            ),
          // Botão para copiar o resumo consolidado do painel (apenas quando houver dados carregados).
          if (_dados != null)
            IconButton(
              // Reduz a densidade visual em telas estreitas de celular.
              visualDensity: telaEstreita ? VisualDensity.compact : null,
              // Ajusta o preenchimento horizontal para economizar espaço na AppBar.
              padding: EdgeInsets.symmetric(horizontal: telaEstreita ? 6 : 8),
              // Define área mínima compacta em celulares.
              constraints: telaEstreita
                  ? const BoxConstraints(minWidth: 34, minHeight: 34)
                  : null,
              icon: const Icon(Icons.content_copy_rounded, size: 20),
              tooltip: 'Copiar resumo do painel',
              onPressed: _copiarRelatorio,
            ),
          // Botão para forçar a atualização imediata dos dados do painel.
          IconButton(
            // Reduz a densidade visual em telas estreitas de celular.
            visualDensity: telaEstreita ? VisualDensity.compact : null,
            // Ajusta o preenchimento horizontal para economizar espaço na AppBar.
            padding: EdgeInsets.symmetric(horizontal: telaEstreita ? 6 : 8),
            // Define área mínima compacta em celulares.
            constraints: telaEstreita
                ? const BoxConstraints(minWidth: 34, minHeight: 34)
                : null,
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'Atualizar painel',
            onPressed: _carregando ? null : () => _carregar(),
          ),
          // Botão reutilizável para alternar dinamicamente entre tema claro e escuro.
          BotaoAlternarTema(compacto: telaEstreita),
          // Avatar do usuário logado com menu suspenso de ações e logout.
          const MarcaAppBar(),
        ],
        // Linha divisória sutil na borda inferior da barra de navegação.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: context.hairline, height: 1),
        ),
      ),
      // Exibe o corpo centralizado dentro do Scaffold próprio.
      body: conteudoCentral,
    );
  }

  /// Constrói o corpo principal da tela alternando entre spinner, erro ou lista com os dados.
  Widget _corpo() {
    // Se está carregando pela primeira vez e não há dados em cache, exibe o indicador de progresso central.
    if (_carregando && _dados == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // Se ocorreu um erro e não existem dados para mostrar, exibe o componente de erro com botão de retry.
    if (_erro != null && _dados == null) {
      return EstadoErro(
        titulo: 'Não foi possível carregar o painel',
        mensagem: _erro!,
        aoTentar: () => _carregar(),
      );
    }

    // A partir deste ponto os dados com certeza estão disponíveis.
    final d = _dados!;
    final r = d.resumo;

    // Calcula a maior quantidade de vendas entre os itens para calibrar a escala das barras de proporção.
    final maiorVenda = d.maisVendidos.fold<int>(
      1,
      (m, i) => i.vendas > m ? i.vendas : m,
    );
    // Calcula o maior estoque entre os itens em excesso para dimensionar as barras de excesso.
    final maiorEstoqueAlto = d.estoqueAlto.fold<int>(
      1,
      (m, i) => i.estoque > m ? i.estoque : m,
    );

    // Permite puxar a tela para baixo (pull-to-refresh) para atualizar os dados.
    return RefreshIndicator(
      onRefresh: () => _carregar(silencioso: true),
      child: ListView(
        // Garante que a rolagem funcione mesmo quando o conteúdo for menor que a altura da tela.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          // Cabeçalho com saudação personalizada atualizada pelo notificador de usuário da sessão e atalho de cópia.
          ValueListenableBuilder<Usuario?>(
            valueListenable: Sessao.instance.usuarioNotifier,
            builder: (_, u, __) => _Cabecalho(
              nome: (u ?? Sessao.instance.usuario)?.primeiroNome ?? '',
              aoCopiarResumo: _copiarRelatorio,
            ),
          ),
          const SizedBox(height: 18),
          // Cartão de destaque com atalho direto para o provador e cadastro de calçados.
          _CartaoProvador(
            onTap: _abrirCatalogo,
            onNovoModelo: _abrirNovoCadastro,
          ),
          const SizedBox(height: 14),
          // Grade com os 4 cartões de indicadores-chave de desempenho (KPIs).
          _GradeKpis(resumo: r),
          // Se a API retornou os registros de menor e maior estoque do endpoint GET /dashboard/, exibe a seção.
          if (d.menorEstoque != null || d.maiorEstoque != null) ...[
            const SizedBox(height: 14),
            _DestaquesApiDashboard(
              menor: d.menorEstoque,
              maior: d.maiorEstoque,
              aoTocarModelo: _abrirModelo,
            ),
          ],
          const SizedBox(height: 22),
          // Seção listando os modelos com mais saídas e vendas nos últimos 30 dias.
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
          // Seção exibindo modelos que atingiram o limite mínimo de estoque (atenção para reposição).
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
                  // Desabilita o botão de reposição rápida enquanto o mesmo item está sendo reposto.
                  onRepor:
                      (Sessao.instance.usuario?.podeGerenciarProdutos ??
                                  false) &&
                              !_repondoIds.contains(item.id)
                      ? () => _reporRapido(item)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Seção que aponta calçados com estoque elevado acima do limite estipulado.
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
          // Rodapé com os canais de contato da loja.
          const RodapeContato(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- cabeçalho

/// Componente visual que exibe a saudação temporal (Bom dia/Boa tarde/Boa noite),
/// o nome do usuário autenticado e a data corrente por extenso.
class _Cabecalho extends StatelessWidget {
  // Primeiro nome do usuário para saudar amigavelmente.
  final String nome;
  // Ação opcional para copiar o resumo consolidado do painel diretamente do cabeçalho.
  final VoidCallback? aoCopiarResumo;
  const _Cabecalho({required this.nome, this.aoCopiarResumo});

  /// Define a saudação conforme o horário atual do dispositivo.
  String get _saudacao {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Bom dia';
    if (hora < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    // Data atual para cálculo do dia e mês.
    final hoje = DateTime.now();
    // Monta a string no formato: "Quarta-feira, 4 de novembro".
    final data =
        '${_diasSemana[hoje.weekday - 1]}, ${hoje.day} de ${_meses[hoje.month - 1]}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Coluna com saudação e data atual ocupa o espaço principal disponível.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Texto de saudação e nome do usuário com tipografia de destaque.
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
              // Exibe a data atual por extenso.
              Text(
                data,
                style: TextStyle(fontSize: 13.5, color: context.textMuted),
              ),
            ],
          ),
        ),
        // Botão discreto no cabeçalho para copiar o resumo em texto para WhatsApp.
        if (aoCopiarResumo != null)
          OutlinedButton.icon(
            onPressed: aoCopiarResumo,
            icon: const Icon(Icons.content_copy_rounded, size: 15),
            label: const Text('Copiar resumo'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 36),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// Cartão com cor de destaque que serve como atalho principal para o provador virtual
/// e oferece botão secundário para cadastrar novos produtos.
class _CartaoProvador extends StatelessWidget {
  // Ação ao tocar no corpo principal do cartão.
  final VoidCallback onTap;
  // Ação ao tocar no botão de novo cadastro.
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
          // Área clicável principal que abre o catálogo e provador.
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Círculo translúcido com o ícone de fita métrica/provador.
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
                    // Título e descrição chamativa sobre as funcionalidades do provador.
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
                    // Seta indicativa de navegação à direita.
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Botão inferior escurecido para cadastro rápido de novo modelo (somente para Dono/Gerente).
          if (Sessao.instance.usuario?.podeGerenciarProdutos ?? false) ...[
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
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------- KPIs

/// Grade responsiva com os 4 cartões de indicadores principais do painel.
class _GradeKpis extends StatelessWidget {
  // Objeto de resumo com os totais consolidados.
  final ResumoDashboard resumo;
  const _GradeKpis({required this.resumo});

  @override
  Widget build(BuildContext context) {
    // Soma total de alertas (produtos acabando + produtos com excesso).
    final alertas = resumo.modelosAcabando + resumo.modelosComExcesso;

    // Lista com a definição dos 4 KPIs da loja.
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

    // Constrói o layout adaptando de 2 para 4 colunas em telas maiores.
    return LayoutBuilder(
      builder: (context, c) {
        // Se a largura disponível for >= 600px, distribui em 4 colunas; senão em 2.
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

/// Cartão individual que exibe um indicador (ícone, valor numérico e rótulo).
class _Kpi extends StatelessWidget {
  // Ícone representativo do indicador.
  final IconData icone;
  // Nome/descrição do indicador.
  final String rotulo;
  // Valor numérico formatado em texto.
  final String valor;
  // Cor opcional de destaque (usada por exemplo em amarelo/alerta).
  final Color? cor;

  const _Kpi({
    required this.icone,
    required this.rotulo,
    required this.valor,
    this.cor,
  });

  @override
  Widget build(BuildContext context) {
    // Aplica a cor personalizada ou a cor de destaque do tema.
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
          // Caixa arredondada com o ícone colorido.
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
          // Valor numérico em tipografia grande e destacada.
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
          // Rótulo textual explicativo.
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

/// Contêiner estilizado para agrupar uma seção de informações do painel.
class _Secao extends StatelessWidget {
  // Título da seção (ex: "Mais vendidos").
  final String titulo;
  // Subtítulo explicativo (ex: "Últimos 30 dias").
  final String subtitulo;
  // Badge/selo numérico opcional no cabeçalho da seção.
  final Widget? selo;
  // Mensagem a exibir caso a lista de linhas esteja vazia.
  final String vazio;
  // Ícone ilustrativo para o estado vazio.
  final IconData iconeVazio;
  // Lista de widgets a serem renderizados como linhas dentro da seção.
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
          // Cabeçalho da seção com título, subtítulo e selo opcional.
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
                // Exibe o selo se fornecido.
                if (selo != null) selo!,
              ],
            ),
          ),
          // Se não houver itens, exibe mensagem descritiva amigável.
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
            // Renderiza as linhas separadas por divisores finos.
            for (var i = 0; i < linhas.length; i++) ...[
              Divider(color: context.hairline),
              linhas[i],
            ],
        ],
      ),
    );
  }
}

/// Linha que representa um item no ranking de mais vendidos.
class _LinhaRanking extends StatelessWidget {
  // Posição no ranking (1, 2, 3...).
  final int posicao;
  // Dados do calçado agregados no item de dashboard.
  final ItemDashboard item;
  // Proporção de 0.0 a 1.0 em relação ao líder para desenho da barra.
  final double proporcao;
  // Ação disparada ao tocar na linha.
  final VoidCallback onTap;

  const _LinhaRanking({
    required this.posicao,
    required this.item,
    required this.proporcao,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Identifica se este item é o 1º lugar do ranking para receber destaque visual.
    final primeiro = posicao == 1;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            // Círculo com o número da posição (preenchido para o 1º lugar).
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
            // Nome, marca e barra de proporção animada.
            Expanded(
              child: _NomeEBarra(
                item: item,
                proporcao: proporcao,
                cor: context.accent,
              ),
            ),
            const SizedBox(width: 14),
            // Quantidade total de vendas registradas no período.
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

/// Linha que representa um calçado nas listas de estoque crítico ou em excesso.
class _LinhaEstoque extends StatelessWidget {
  // Dados do calçado.
  final ItemDashboard item;
  // Proporção de 0.0 a 1.0 para calibrar a barra de progresso.
  final double proporcao;
  // Cor semântica da barra e do selo (alerta ou informação).
  final Color cor;
  // Rótulo textual (ex: "Esgotado", "Acabando" ou "Excesso").
  final String rotulo;
  // Ação ao tocar na linha para abrir o detalhe.
  final VoidCallback onTap;
  // Callback opcional para o botão de reposição rápida (+5 unidades).
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
            // Nome, marca e barra visual de estoque.
            Expanded(
              child: _NomeEBarra(item: item, proporcao: proporcao, cor: cor),
            ),
            const SizedBox(width: 12),
            // Contagem de unidades e selo de status.
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
            // Se fornecido o callback de reposição, exibe o botão rápido "+5 un.".
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

/// Widget auxiliar que agrupa o nome do modelo, a marca e a barra animada de proporção.
class _NomeEBarra extends StatelessWidget {
  // Modelo exibido na linha.
  final ItemDashboard item;
  // Proporção de preenchimento da barra.
  final double proporcao;
  // Cor da barra.
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
        // Nome do calçado com corte por reticências se for muito longo.
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
        // Marca do calçado em cor secundária discreta.
        Text(
          item.marca,
          style: TextStyle(fontSize: 12, color: context.textMuted),
        ),
        const SizedBox(height: 8),
        // Barra proporcional animada.
        _Barra(valor: proporcao, cor: cor),
      ],
    );
  }
}

/// Barra proporcional desenhada manualmente sem bibliotecas externas pesadas de gráficos,
/// utilizando animação suave com curva cúbica easeOut.
class _Barra extends StatelessWidget {
  // Valor de 0.0 a 1.0 que indica o preenchimento da barra.
  final double valor;
  // Cor do preenchimento da barra.
  final Color cor;

  const _Barra({required this.valor, required this.cor});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(
        children: [
          // Fundo cinza/linha sutil representando 100% da largura.
          Container(height: 6, color: context.hairline),
          // Animação que transiciona a largura de 0 até o valor final da proporção.
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

/// Pequeno selo colorido (badge) com fundo translúcido e bordas arredondadas.
class _Selo extends StatelessWidget {
  // Texto exibido no selo.
  final String texto;
  // Cor base do selo (o fundo usa transparência dessa cor).
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

/// Destaques de menor e maior estoque vindos diretamente da rota oficial GET /dashboard/ do backend.
class _DestaquesApiDashboard extends StatelessWidget {
  // Objeto do produto com menor estoque retornado pela API.
  final ExtremoEstoque? menor;
  // Objeto do produto com maior estoque retornado pela API.
  final ExtremoEstoque? maior;
  // Callback disparado quando o usuário toca em um dos produtos em destaque.
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
          // Cabeçalho da seção com ícone de estatísticas e título.
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 18, color: context.accent),
              const SizedBox(width: 8),
              Text(
                'Destaques de estoque',
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
          // Disposição lado a lado dos dois extremos de estoque.
          Row(
            children: [
              // Cartão de menor estoque (alerta vermelho/danger).
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
                          // Nome do produto com menor estoque.
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
                          // Saldo de unidades disponíveis.
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
              // Espaçamento entre os dois cartões quando ambos existirem.
              if (menor != null && maior != null) const SizedBox(width: 10),
              // Cartão de maior estoque (destaque azul/info).
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
                          // Nome do produto com maior estoque.
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
                          // Saldo de unidades disponíveis.
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

/// Modal inferior (bottom sheet) que lista as movimentações de saída de estoque
/// registradas na rota GET /stock-exit/ da API para auditoria.
class _ModalHistoricoSaidas extends StatefulWidget {
  // Callback executado ao tocar em uma saída para abrir o produto correspondente.
  final void Function(int id) aoAbrirModelo;

  const _ModalHistoricoSaidas({required this.aoAbrirModelo});

  @override
  // Cria o estado do modal.
  State<_ModalHistoricoSaidas> createState() => _ModalHistoricoSaidasState();
}

/// Estado do modal de histórico de saídas com controle de carregamento, erro e paginação.
class _ModalHistoricoSaidasState extends State<_ModalHistoricoSaidas> {
  // Flag que indica carregamento das saídas.
  bool _carregando = true;
  // Mensagem de erro caso a rota falhe.
  String? _erro;
  // Lista dos registros de saídas retornados.
  List<SaidaEstoque> _saidas = [];

  @override
  // Dispara a busca assim que o modal é aberto.
  void initState() {
    super.initState();
    _carregar();
  }

  /// Busca os últimos 30 registros de saída de estoque chamando o ApiService.
  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      // Requisita a página 1 com tamanho de 30 registros.
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
      // Limita a altura máxima do modal a 85% da tela.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Puxador cinza arredondado no topo do modal.
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.hairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Cabeçalho do modal com título, descrição e botões de atualizar e fechar.
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
                        'Auditoria de saídas e baixas registradas',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Botão para recarregar o histórico.
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Recarregar histórico',
                  onPressed: _carregando ? null : _carregar,
                ),
                // Botão para fechar o modal.
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(color: context.hairline, height: 1),
          // Conteúdo rolável do modal reutilizando a lista compartilhada de auditoria.
          Expanded(
            child: ListaSaidasAuditadas(
              carregando: _carregando,
              erro: _erro,
              saidas: _saidas,
              aoTentar: _carregar,
              aoAbrirModelo: widget.aoAbrirModelo,
            ),
          ),
        ],
      ),
    );
  }
}
