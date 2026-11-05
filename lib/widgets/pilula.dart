// Importa os componentes gráficos do Flutter
import 'package:flutter/material.dart';
// Importa o tema e atalhos de cor do aplicativo
import '../theme/app_theme.dart';

/// Componente visual em formato de tag/chip pequeno ("Pílula") utilizado para exibir
/// rótulos de tipo de calçado, largura da forma, status de estoque e categorias.
class Pilula extends StatelessWidget {
  /// Texto exibido dentro da etiqueta
  final String texto;

  /// Se verdadeiro, utiliza a cor de destaque principal do tema
  final bool destaque;

  /// Cor personalizada opcional para o fundo e o texto da etiqueta
  final Color? cor;

  /// Ícone opcional exibido antes do texto
  final IconData? icone;

  /// Construtor da Pílula com texto obrigatório e estilizações opcionais
  const Pilula({
    // Chave do widget
    super.key,
    // Texto do rótulo obrigatório
    required this.texto,
    // Destaque falso por padrão
    this.destaque = false,
    // Cor personalizada opcional
    this.cor,
    // Ícone opcional
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    // Determina a cor final a ser aplicada (customizada, acento do tema ou atenuada)
    final corEfetiva = cor ?? (destaque ? context.accent : context.textMuted);
    // Define se o fundo deve ser preenchido (quando tem destaque ou cor explícita)
    final preenchido = destaque || cor != null;

    // Renderiza a caixa com preenchimento interno e bordas arredondadas
    return Container(
      // Espaçamento interno de 8px nas laterais e 3.5px acima e abaixo
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      // Decoração visual de borda e fundo
      decoration: BoxDecoration(
        // Aplica transparência de 13% sobre a cor caso seja preenchida
        color: preenchido ? corEfetiva.withValues(alpha: 0.13) : null,
        // Bordas arredondadas com raio de 6px
        borderRadius: BorderRadius.circular(6),
        // Adiciona borda sutil apenas se não for preenchido
        border: preenchido
            ? null
            : Border.all(color: corEfetiva.withValues(alpha: 0.35)),
      ),
      // Linha contendo o ícone opcional e o texto
      child: Row(
        // Ocupa apenas a largura necessária para o conteúdo
        mainAxisSize: MainAxisSize.min,
        children: [
          // Renderiza o ícone se tiver sido informado
          if (icone != null) ...[
            Icon(icone, size: 12.5, color: corEfetiva),
            // Espaçamento de 4px entre o ícone e o texto
            const SizedBox(width: 4),
          ],
          // Exibe o texto com peso semi-bold e tamanho 11.5
          Text(
            texto,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: corEfetiva,
            ),
          ),
        ],
      ),
    );
  }
}
