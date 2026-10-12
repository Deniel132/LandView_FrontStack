import 'package:flutter/material.dart';

import '../config/loja.dart';
import '../theme/app_theme.dart';

class LogoLoja extends StatelessWidget {
  final double tamanho;
  final bool sombra;

  const LogoLoja({super.key, this.tamanho = 40, this.sombra = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: AppColors.brand,
        shape: BoxShape.circle,
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
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        Loja.logoAsset,
        width: tamanho,
        height: tamanho,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        semanticLabel: Loja.nomeCompleto,
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

class MarcaAppBar extends StatelessWidget {
  const MarcaAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 4, right: 14),
      child: LogoLoja(tamanho: 30),
    );
  }
}
