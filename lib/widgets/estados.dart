import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Faixa discreta de aviso (erro, alerta ou informação) usada em formulários
/// e no topo de seções.
class FaixaAviso extends StatelessWidget {
  final String mensagem;
  final Color cor;
  final IconData icone;

  const FaixaAviso({
    super.key,
    required this.mensagem,
    required this.cor,
    required this.icone,
  });

  const FaixaAviso.erro({super.key, required this.mensagem})
    : cor = AppColors.danger,
      icone = Icons.error_outline_rounded;

  const FaixaAviso.alerta({super.key, required this.mensagem})
    : cor = AppColors.hazard,
      icone = Icons.warning_amber_rounded;

  const FaixaAviso.info({super.key, required this.mensagem})
    : cor = AppColors.info,
      icone = Icons.info_outline_rounded;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icone, size: 19, color: cor),
          const SizedBox(width: 10),
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

/// Estado de erro com mensagem e botão para tentar novamente.
class EstadoErro extends StatelessWidget {
  final String titulo;
  final String mensagem;
  final VoidCallback aoTentar;

  const EstadoErro({
    super.key,
    this.titulo = 'Não foi possível carregar os dados',
    required this.mensagem,
    required this.aoTentar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const SizedBox(height: 14),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.textStrong,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: context.textMuted),
            ),
            const SizedBox(height: 18),
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

/// Estado vazio padronizado para listas sem resultados.
class EstadoVazio extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String subtitulo;
  final String? rotuloAcao;
  final VoidCallback? aoAcionar;

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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icone, size: 26, color: context.accent),
            ),
            const SizedBox(height: 14),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.textStrong,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: context.textMuted),
            ),
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

