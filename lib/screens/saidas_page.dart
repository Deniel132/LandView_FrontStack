// Importa os componentes visuais do Flutter
import 'package:flutter/material.dart';
// Importa o modelo que representa um registro de auditoria de saída de estoque
import '../models/saida_estoque.dart';
// Importa o serviço singleton de comunicação com a API
import '../services/api_service.dart';
// Importa o gerenciador de sessão para checar permissão de auditoria do Proprietário
import '../services/sessao.dart';
// Importa as cores, raios e helpers de tema claro/escuro
import '../theme/app_theme.dart';
// Importa componentes reutilizáveis de erro, vazio e overlay modal de loading
import '../widgets/estados.dart';
// Importa a tela de detalhes do produto aberta ao tocar em uma saída
import 'detalhe_page.dart';

/// Tela (aba) dedicada ao Histórico de Saídas e Baixas de Estoque para auditoria do Proprietário.
/// Consome `GET /stock-exit/` e permite abrir os detalhes do calçado baixado sem cliques duplicados.
class SaidasPage extends StatefulWidget {
  /// Notificador opcional disparado quando a Navbar solicita atualização da aba ativa
  final ValueNotifier<int>? gatilhoAtualizacao;

  // Construtor constante da página de auditoria de saídas
  const SaidasPage({super.key, this.gatilhoAtualizacao});

  @override
  State<SaidasPage> createState() => _SaidasPageState();
}

/// Estado da aba de auditoria gerenciando busca paginada, carregamento e abertura segura de produto.
class _SaidasPageState extends State<SaidasPage> {
  // Indica se a lista de saídas está carregando
  bool _carregando = true;

  // Trava cliques repetidos enquanto abre um calçado na API
  bool _abrindoModelo = false;

  // Mensagem de erro caso falhe a consulta na API
  String? _erro;

  // Lista com os registros de saída retornados
  List<SaidaEstoque> _saidas = [];

  @override
  void initState() {
    super.initState();
    // Escuta o gatilho de atualização vindo da Navbar
    widget.gatilhoAtualizacao?.addListener(_aoDispararGatilho);
    // Carrega os registros de saída ao abrir a aba
    _carregar();
  }

  @override
  void didUpdateWidget(covariant SaidasPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Atualiza o ouvinte se o notificador mudar
    if (oldWidget.gatilhoAtualizacao != widget.gatilhoAtualizacao) {
      oldWidget.gatilhoAtualizacao?.removeListener(_aoDispararGatilho);
      widget.gatilhoAtualizacao?.addListener(_aoDispararGatilho);
    }
  }

  @override
  void dispose() {
    // Remove o ouvinte ao desmontar o widget
    widget.gatilhoAtualizacao?.removeListener(_aoDispararGatilho);
    super.dispose();
  }

  /// Atualiza a auditoria de saídas quando acionado pela Navbar
  void _aoDispararGatilho() {
    _carregar(silencioso: _saidas.isNotEmpty);
  }

  /// Consulta os últimos registros de saída na rota `GET /stock-exit/`
  Future<void> _carregar({bool silencioso = false}) async {
    // Se não for atualização silenciosa, exibe indicador circular de carregamento
    if (!silencioso) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }
    try {
      // Busca a primeira página com os últimos 30 registros de auditoria
      final lista = await ApiService.instance.listarSaidas(page: 1, pageSize: 30);
      if (!mounted) return;
      setState(() {
        _saidas = lista;
        _erro = null;
        _carregando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        if (_saidas.isEmpty) _erro = e.mensagem;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        if (_saidas.isEmpty) {
          _erro = 'Não foi possível obter o histórico de saídas.';
        }
      });
    }
  }

  /// Abre o detalhe do produto referente à saída tocada, exibindo overlay de loading e bloqueando múltiplos cliques
  Future<void> _abrirModelo(int id) async {
    // Ignora novos cliques enquanto uma consulta estiver em andamento
    if (_abrindoModelo) return;
    _abrindoModelo = true;
    var loadingAberto = true;

    // Exibe overlay modal de carregamento centralizado
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: OverlayCarregando()),
      ),
    ).whenComplete(() => loadingAberto = false);

    try {
      // Busca os detalhes completos do calçado antes de navegar
      final calcado = await ApiService.instance.buscar(id);
      if (!mounted) return;
      if (loadingAberto) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingAberto = false;
      }
      // Abre a tela de detalhe do calçado
      await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => DetalhePage(calcado: calcado)),
      );
      // Recarrega silenciosamente caso novas vendas ou ajustes tenham ocorrido no detalhe
      if (mounted) _carregar(silencioso: true);
    } on ApiException catch (e) {
      if (loadingAberto && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingAberto = false;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.mensagem)));
    } catch (_) {
      if (loadingAberto && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingAberto = false;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o produto. Tente novamente.'),
          ),
        );
    } finally {
      if (loadingAberto && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _abrindoModelo = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Garante que apenas o Proprietário tenha acesso visual à tela de auditoria
    if (!(Sessao.instance.usuario?.podeVerAuditoria ?? false)) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: FaixaAviso.alerta(
              mensagem:
                  'A auditoria de saídas é exclusiva da conta de Proprietário.',
            ),
          ),
        ),
      );
    }

    // Conteúdo centralizado e limitado a 720px para manter harmonia com o Painel e o Catálogo
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cartão de cabeçalho explicativo da auditoria de saídas
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.cardSurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: context.hairline),
                ),
                child: Row(
                  children: [
                    // Ícone circular azul representando auditoria
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        size: 20,
                        color: context.accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Título e descrição da tela de auditoria
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Histórico de Saídas de Estoque',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: context.textStrong,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Auditoria das últimas vendas e baixas registradas na loja',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Corpo principal com suporte a puxar para atualizar (pull-to-refresh)
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _carregar(silencioso: true),
                child: ListaSaidasAuditadas(
                  carregando: _carregando,
                  erro: _erro,
                  saidas: _saidas,
                  aoTentar: () => _carregar(),
                  aoAbrirModelo: _abrirModelo,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista reutilizável de registros de auditoria de saídas de estoque (usada na aba Saídas e no modal).
class ListaSaidasAuditadas extends StatelessWidget {
  /// Indica se os dados estão em carregamento
  final bool carregando;

  /// Mensagem de erro opcional caso a consulta falhe
  final String? erro;

  /// Lista de saídas obtida da API
  final List<SaidaEstoque> saidas;

  /// Callback para tentar recarregar em caso de erro
  final VoidCallback aoTentar;

  /// Callback disparado ao tocar em uma saída para abrir o calçado
  final void Function(int idProduto) aoAbrirModelo;

  // Construtor constante com parâmetros obrigatórios
  const ListaSaidasAuditadas({
    super.key,
    required this.carregando,
    required this.erro,
    required this.saidas,
    required this.aoTentar,
    required this.aoAbrirModelo,
  });

  @override
  Widget build(BuildContext context) {
    // Se estiver carregando pela primeira vez, exibe o indicador circular de progresso
    if (carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    // Se falhou, apresenta mensagem amigável com botão de tentar novamente
    if (erro != null) {
      return EstadoErro(
        titulo: 'Não foi possível obter o histórico',
        mensagem: erro!,
        aoTentar: aoTentar,
      );
    }
    // Se ainda não houver nenhuma saída cadastrada, exibe estado neutro ilustrado
    if (saidas.isEmpty) {
      return const EstadoVazio(
        icone: Icons.assignment_outlined,
        titulo: 'Nenhuma saída registrada',
        subtitulo: 'As vendas e baixas de estoque aparecerão aqui.',
      );
    }

    // Lista com separadores finos exibindo cada registro de saída retornado
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: saidas.length,
      separatorBuilder: (_, __) => Divider(color: context.hairline, height: 1),
      itemBuilder: (context, i) {
        final s = saidas[i];
        // Nome do calçado ou ID de fallback caso não esteja no catálogo
        final nome = s.nomeProduto ?? 'Produto #${s.idProduto}';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          // Ícone circular de saída em vermelho
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
          // Nome do modelo baixado
          title: Text(
            nome,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.textStrong,
            ),
          ),
          // Identificadores de registro, estoque e usuário responsável pela baixa
          subtitle: Text(
            'Registro #${s.id} · Estoque #${s.idEstoque} · Usuário #${s.idUsuario}',
            style: TextStyle(fontSize: 11.5, color: context.textMuted),
          ),
          // Quantidade reduzida com sinal negativo em destaque
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
          // Ao tocar na saída, abre os detalhes do produto correspondente
          onTap: () => aoAbrirModelo(s.idProduto),
        );
      },
    );
  }
}

