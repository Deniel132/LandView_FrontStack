// Importa os componentes visuais do Flutter
import 'package:flutter/material.dart';

// Importa as constantes da loja (caminho do asset do logotipo e nomes)
import '../config/loja.dart';
// Importa o ponto de entrada do aplicativo para alternar dinamicamente entre tema claro e escuro
import '../main.dart';
// Importa o modelo de usuário autenticado
import '../models/usuario.dart';
// Importa a tela de criação de contas da equipe (exclusiva do e-mail mãe)
import '../screens/criar_conta_page.dart';
// Importa a tela de login para redirecionamento após logout
import '../screens/login_page.dart';
// Importa o gerenciador da sessão ativa
import '../services/sessao.dart';
// Importa as configurações visuais de tema e cores
import '../theme/app_theme.dart';

/// Componente visual que exibe o logotipo circular da Land View com tratamento de sombra e fallback.
class LogoLoja extends StatelessWidget {
  /// Diâmetro em pixels do círculo do logotipo
  final double tamanho;

  /// Se verdadeiro, projeta uma sombra suave sob o logotipo
  final bool sombra;

  /// Construtor com valores padrão (diâmetro 40px e sem sombra)
  const LogoLoja({super.key, this.tamanho = 40, this.sombra = false});

  @override
  Widget build(BuildContext context) {
    // Caixa contenedora circular com dimensões fixas
    return Container(
      // Largura definida
      width: tamanho,
      // Altura definida
      height: tamanho,
      // Decoração visual do círculo
      decoration: BoxDecoration(
        // Cor azul de fundo da marca
        color: AppColors.brand,
        // Formato circular
        shape: BoxShape.circle,
        // Sombra azulada projetada caso a flag sombra seja verdadeira
        boxShadow: sombra
            ? [
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: 0.35),
                  blurRadius: tamanho * 0.3,
                  offset: Offset(0, tamanho * 0.1),
                ),
              ]
            : null,
      ),
      // Corta a imagem no formato circular
      clipBehavior: Clip.antiAlias,
      // Renderiza a imagem oficial dos assets da loja
      child: Image.asset(
        Loja.logoAsset,
        width: tamanho,
        height: tamanho,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        semanticLabel: Loja.nomeCompleto,
        // Em caso de falha ao carregar a imagem, renderiza texto "LV" centralizado
        errorBuilder: (_, __, ___) => Center(
          child: Text(
            'LV',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: tamanho * 0.36,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão de conta do atendente/vendedor exibido no canto superior direito das AppBars.
/// Exibe um avatar circular com as iniciais do usuário logado e abre um menu suspenso
/// com informações da conta, papel (role), status de conexão e opções de alterar nome e sair.
class MarcaAppBar extends StatelessWidget {
  // Construtor constante do componente da AppBar
  const MarcaAppBar({super.key});

  /// Abre uma janela de diálogo para o usuário atualizar seu nome de exibição no app
  Future<void> _editarNome(BuildContext context, Usuario? usuario) async {
    // Inicializa o controlador do campo com o nome atual do usuário
    final controller = TextEditingController(text: usuario?.nome ?? '');

    // Exibe o AlertDialog modal e aguarda o fechamento
    final novoNome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        // Título do diálogo
        title: const Text(
          'Identificação do atendente',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        // Campo de texto para digitar o novo nome
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Seu nome ou apelido',
            hintText: 'Ex.: Arthur Silva',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        // Botões de ação do diálogo (Cancelar e Salvar)
        actions: [
          // Botão Cancelar
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: ctx.textMuted)),
          ),
          // Botão Salvar
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42)),
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    // Se o usuário confirmou um nome válido, atualiza na sessão
    if (novoNome != null && novoNome.trim().isNotEmpty) {
      Sessao.instance.atualizarNome(novoNome);
    }
  }

  /// Abre a tela de criação de nova conta da equipe (permitida somente ao e-mail mãe)
  Future<void> _abrirCriarConta(BuildContext context, Usuario? usuario) async {
    // Bloqueia o acesso caso o usuário logado não seja o e-mail mãe autorizado
    if (!(usuario?.podeCriarContas ?? false)) return;
    // Navega para a tela de cadastro de conta aguardando o e-mail recém-criado
    await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CriarContaPage()),
    );
  }

  /// Realiza o logout do usuário limpando a sessão e redirecionando para a tela de login
  void _sair(BuildContext context) {
    // Limpa token e usuário da memória
    Sessao.instance.encerrar();
    // Redireciona para o LoginPage removendo todas as rotas anteriores da pilha
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ouve reativamente alterações de usuário na sessão para manter a AppBar sempre sincronizada
    return ValueListenableBuilder<Usuario?>(
      valueListenable: Sessao.instance.usuarioNotifier,
      builder: (context, usuarioNotificado, _) {
        // Obtém o usuário ativo
        final usuario = usuarioNotificado ?? Sessao.instance.usuario;
        // Iniciais para renderização no avatar
        final iniciais = usuario?.iniciais ?? 'U';
        // Nome de exibição
        final nome = usuario?.nome ?? 'Conta conectada';
        // E-mail cadastrado
        final email = usuario?.email ?? 'Sessão ativa';

        // Preenchimento à direita da AppBar
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          // Menu pop-up acionado ao tocar no avatar
          child: PopupMenuButton<String>(
            tooltip: 'Conta',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            // Trata as opções selecionadas pelo usuário
            onSelected: (valor) {
              // Abre diálogo de alteração do nome de exibição
              if (valor == 'editar_nome') {
                _editarNome(context, usuario);
              // Abre a tela de criação de conta (exclusivo do e-mail mãe)
              } else if (valor == 'criar_conta') {
                _abrirCriarConta(context, usuario);
              // Encerra a sessão e volta para o login
              } else if (valor == 'sair') {
                _sair(context);
              }
            },
            // Constrói os itens do menu suspenso
            itemBuilder: (_) => [
              // Cabeçalho informativo da conta (não clicável)
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nome do usuário logado
                    Text(
                      nome,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textStrong,
                      ),
                    ),
                    // Papel/cargo do usuário caso informado
                    if (usuario?.perfil != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        usuario!.perfilRotulo,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: context.accent,
                        ),
                      ),
                    ],
                    // E-mail da conta
                    Text(
                      email,
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                  ],
                ),
              ),
              // Linha divisória
              const PopupMenuDivider(),
              // Opção para alterar nome de atendente
              const PopupMenuItem<String>(
                value: 'editar_nome',
                child: Row(
                  children: [
                    // Ícone de edição de perfil
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    // Flexible evita overflow horizontal em menus com fontes maiores
                    Flexible(
                      child: Text(
                        'Alterar nome de exibição',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Opção exclusiva do e-mail mãe (admin@gmail.com) para cadastrar contas de colaboradores
              if (usuario?.podeCriarContas ?? false)
                const PopupMenuItem<String>(
                  value: 'criar_conta',
                  child: Row(
                    children: [
                      // Ícone representativo de adição de colaborador
                      Icon(Icons.person_add_alt_1_outlined, size: 18),
                      SizedBox(width: 10),
                      // Rótulo da ação no menu da conta protegido contra overflow
                      Flexible(
                        child: Text(
                          'Criar nova conta',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              // Opção para desconectar
              const PopupMenuItem<String>(
                value: 'sair',
                child: Row(
                  children: [
                    // Ícone de saída do sistema
                    Icon(Icons.logout_rounded, size: 18),
                    SizedBox(width: 10),
                    // Rótulo da ação protegido contra overflow
                    Flexible(
                      child: Text(
                        'Sair',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // O botão visível na AppBar: o avatar circular com as iniciais
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.brand,
                child: Text(
                  iniciais,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Botão reutilizável para alternar entre tema claro e tema escuro em qualquer tela do aplicativo.
class BotaoAlternarTema extends StatelessWidget {
  /// Reduz o espaçamento horizontal em barras de celular com largura estreita
  final bool compacto;

  /// Construtor constante com espaçamento padrão ou compacto para telas pequenas
  const BotaoAlternarTema({super.key, this.compacto = false});

  @override
  Widget build(BuildContext context) {
    // Detecta se a árvore visual atual está renderizando o tema escuro
    final isDark = context.isDark;

    // Retorna o botão de ícone sincronizado com o notificador global de tema
    return IconButton(
      // Reduz a densidade visual quando posicionado em barras estreitas de celular
      visualDensity: compacto ? VisualDensity.compact : null,
      // Ajusta o preenchimento horizontal para não apertar títulos no celular
      padding: compacto ? const EdgeInsets.symmetric(horizontal: 6) : null,
      // Limita a área mínima no modo compacto para economizar espaço horizontal
      constraints: compacto
          ? const BoxConstraints(minWidth: 34, minHeight: 34)
          : null,
      // Exibe sol para voltar ao claro ou lua para ativar o tema escuro
      icon: Icon(
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        size: 21,
      ),
      // Texto explicativo exibido ao passar o mouse ou segurar o botão
      tooltip: isDark ? 'Usar tema claro' : 'Usar tema escuro',
      // Atualiza o tema globalmente em todas as telas abertas do app
      onPressed: () {
        // Notifica o MaterialApp sobre a troca entre claro e escuro
        MyApp.themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
      },
    );
  }
}
