// Importa os componentes gráficos do Flutter
import 'package:flutter/material.dart';
// Importa as constantes e identificações da marca
import '../config/loja.dart';
// Importa o tema e atalhos de cores da aplicação
import '../theme/app_theme.dart';

/// Widget de rodapé institucional simplificado para telas internas de gestão de estoque.
class RodapeContato extends StatelessWidget {
  // Construtor constante do widget de rodapé
  const RodapeContato({super.key});

  @override
  Widget build(BuildContext context) {
    // Aplica espaçamento vertical de 8 pixels
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      // Exibe a identificação do sistema interno com cor discreta
      child: Text(
        '${Loja.produto} · Sistema Interno de Controle de Estoque',
        // Alinha o texto centralizado na tela
        textAlign: TextAlign.center,
        // Define tamanho de fonte 12 com cor atenuada
        style: TextStyle(fontSize: 12, color: context.textMuted),
      ),
    );
  }
}

/// Versão compacta do rodapé institucional para diálogos e modais menores.
class ContatoCompacto extends StatelessWidget {
  // Construtor constante do widget compacto
  const ContatoCompacto({super.key});

  @override
  Widget build(BuildContext context) {
    // Exibe texto sucinto centralizado
    return Text(
      '${Loja.produto} · Controle Interno de Estoque',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: context.textMuted),
    );
  }
}
