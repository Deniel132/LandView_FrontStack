import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Etiqueta pequena (tipo, forma, status de estoque...).
/// `destaque` usa a cor de destaque do tema ou a [cor] personalizada.
class Pilula extends StatelessWidget {
  final String texto;
  final bool destaque;
  final Color? cor;
  final IconData? icone;

  const Pilula({
    super.key,
    required this.texto,
    this.destaque = false,
    this.cor,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    final corEfetiva = cor ?? (destaque ? context.accent : context.textMuted);
    final preenchido = destaque || cor != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: preenchido ? corEfetiva.withValues(alpha: 0.13) : null,
        borderRadius: BorderRadius.circular(6),
        border: preenchido
            ? null
            : Border.all(color: corEfetiva.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 12.5, color: corEfetiva),
            const SizedBox(width: 4),
          ],
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
