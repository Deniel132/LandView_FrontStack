// Importa os componentes visuais do Flutter
import 'package:flutter/material.dart';

// Importa as constantes da loja (caminho do asset do logotipo e nomes)
import '../config/loja.dart';
// Importa o modelo de usuário autenticado
import '../models/usuario.dart';
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
              if (valor == 'editar_nome') {
                _editarNome(context, usuario);
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
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Alterar nome de exibição'),
                  ],
                ),
              ),
              // Opção para desconectar
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
