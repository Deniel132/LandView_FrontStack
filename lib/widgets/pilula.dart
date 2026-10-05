import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Etiqueta pequena (tipo, forma, alternativa...). `destaque` pinta de verde.
class Pilula extends StatelessWidget {
  final String texto;
  final bool destaque;

  const Pilula({super.key, required this.texto, this.destaque = false});

  @override
  Widget build(BuildContext context) {
    final cor = destaque ? context.accent : context.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: destaque ? cor.withValues(alpha: 0.12) : null,
        borderRadius: BorderRadius.circular(6),
        border: destaque
            ? null
            : Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: cor,
        ),
      ),
    );
  }
}
