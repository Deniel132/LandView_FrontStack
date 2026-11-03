import 'package:flutter/material.dart';

import '../config/loja.dart';
import '../theme/app_theme.dart';

class RodapeContato extends StatelessWidget {
  const RodapeContato({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '${Loja.produto} · Sistema Interno de Controle de Estoque',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: context.textMuted),
      ),
    );
  }
}

class ContatoCompacto extends StatelessWidget {
  const ContatoCompacto({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      '${Loja.produto} · Controle Interno de Estoque',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: context.textMuted),
    );
  }
}
