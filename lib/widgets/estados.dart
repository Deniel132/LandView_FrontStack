// Importa os componentes e estilos visuais do Flutter
import 'package:flutter/material.dart';
// Importa o tema e atalhos de cor do aplicativo
import '../theme/app_theme.dart';

/// Componente visual para exibir uma faixa destacada de aviso, erro ou informação
/// no topo de formulários ou seções da aplicação.
class FaixaAviso extends StatelessWidget {
  /// Mensagem textual a ser exibida para o usuário
  final String mensagem;

  /// Cor principal da borda, ícone e fundo translúcido
  final Color cor;

  /// Ícone ilustrativo exibido ao lado do texto
  final IconData icone;

  /// Construtor genérico da faixa de aviso
  const FaixaAviso({
    // Chave do widget
    super.key,
    // Mensagem obrigatória
    required this.mensagem,
    // Cor obrigatória
    required this.cor,
    // Ícone obrigatório
    required this.icone,
  });

  /// Construtor nomeado para mensagens de erro (utiliza vermelho e ícone de erro)
  const FaixaAviso.erro({super.key, required this.mensagem})
    : cor = AppColors.danger,
      icone = Icons.error_outline_rounded;

  /// Construtor nomeado para mensagens de alerta e atenção (utiliza amarelo âmbar)
  const FaixaAviso.alerta({super.key, required this.mensagem})
    : cor = AppColors.hazard,
      icone = Icons.warning_amber_rounded;

  /// Construtor nomeado para mensagens informativas (utiliza azul)
  const FaixaAviso.info({super.key, required this.mensagem})
    : cor = AppColors.info,
      icone = Icons.info_outline_rounded;

  @override
  Widget build(BuildContext context) {
    // Caixa estilizada com borda e preenchimento suave
    return Container(
      // Espaçamento interno de 14px horizontal e 12px vertical
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      // Decoração visual
      decoration: BoxDecoration(
        // Cor de fundo com 12% de opacidade
        color: cor.withValues(alpha: 0.12),
        // Cantos arredondados padrão
        borderRadius: BorderRadius.circular(AppTheme.radius),
        // Borda sutil com 35% de opacidade da cor principal
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      // Linha horizontal agrupando o ícone e a mensagem
      child: Row(
        children: [
          // Ícone ilustrativo
          Icon(icone, size: 19, color: cor),
          // Espaço horizontal de 10px entre ícone e texto
          const SizedBox(width: 10),
          // O texto ocupa todo o espaço restante e permite quebra de linha
          Expanded(
            child: Text(
              mensagem,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: context.textStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado visual completo exibido quando ocorre falha ao carregar dados da rede,
/// contendo ícone de desconexão, mensagem de erro e botão de tentar novamente.
class EstadoErro extends StatelessWidget {
  /// Título principal do erro (ex: "Não foi possível carregar os dados")
  final String titulo;

  /// Mensagem detalhada com a causa ou instrução para o usuário
  final String mensagem;

  /// Função de callback disparada quando o usuário clica em "Tentar novamente"
  final VoidCallback aoTentar;

  /// Construtor do estado de erro
  const EstadoErro({
    super.key,
    this.titulo = 'Não foi possível carregar os dados',
    required this.mensagem,
    required this.aoTentar,
  });

  @override
  Widget build(BuildContext context) {
    // Centraliza o conteúdo na área disponível
    return Center(
      // Permite rolagem caso a tela seja pequena
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        // Organiza os elementos verticalmente
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Círculo translúcido com o ícone de nuvem desconectada
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 28,
                color: AppColors.danger,
              ),
            ),
            // Espaçamento de 14px
            const SizedBox(height: 14),
            // Título do erro em destaque
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.textStrong,
              ),
            ),
            // Espaçamento de 6px
            const SizedBox(height: 6),
            // Mensagem detalhada com cor atenuada
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: context.textMuted),
            ),
            // Espaçamento de 18px
            const SizedBox(height: 18),
            // Botão com ícone para recarregar a requisição
            OutlinedButton.icon(
              onPressed: aoTentar,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado visual padronizado para listas vazias ou buscas que não retornaram resultados.
class EstadoVazio extends StatelessWidget {
  /// Ícone representativo da lista vazia (ex: caixa aberta, busca vazia)
  final IconData icone;

  /// Título de aviso (ex: "Nenhum calçado encontrado")
  final String titulo;

  /// Mensagem secundária explicativa
  final String subtitulo;

  /// Texto do botão de ação opcional (ex: "Cadastrar primeiro modelo")
  final String? rotuloAcao;

  /// Callback executado ao clicar no botão de ação opcional
  final VoidCallback? aoAcionar;

  /// Construtor do estado vazio
  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    required this.subtitulo,
    this.rotuloAcao,
    this.aoAcionar,
  });

  @override
  Widget build(BuildContext context) {
    // Centraliza o conteúdo na tela
    return Center(
      // Permite rolagem vertical caso o teclado ou tela reduza o espaço
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Círculo com a cor de destaque do tema
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icone, size: 26, color: context.accent),
            ),
            // Espaço de 14px
            const SizedBox(height: 14),
            // Título do estado vazio
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.textStrong,
              ),
            ),
            // Espaço de 4px
            const SizedBox(height: 4),
            // Subtítulo descritivo
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: context.textMuted),
            ),
            // Se houver ação e rótulo, exibe botão de ação
            if (rotuloAcao != null && aoAcionar != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: aoAcionar,
                child: Text(rotuloAcao!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
