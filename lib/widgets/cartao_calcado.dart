import 'package:flutter/material.dart';
import '../models/calcado.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import 'pilula.dart';

/// Linha do catálogo: miniatura, nome, marca, tipo/forma e preço.
///
/// O toque no cartão abre a tela com os detalhes do calçado.
class CartaoCalcado extends StatelessWidget {
  final Calcado calcado;
  final VoidCallback? onTap;

  const CartaoCalcado({super.key, required this.calcado, this.onTap});

  String get _faixa {
    if (calcado.tamanhos.isEmpty) return 'sem tabela';
    final menor = calcado.tamanhos.first.numeracao;
    final maior = calcado.tamanhos.last.numeracao;
    return 'nº ${Formato.numeracao(menor)} a ${Formato.numeracao(maior)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: context.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.28 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _Miniatura(calcado: calcado),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        calcado.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: context.textStrong,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        calcado.marca,
                        style: TextStyle(fontSize: 13, color: context.textMuted),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Pilula(texto: calcado.tipo.rotulo, destaque: true),
                          Pilula(texto: 'Forma ${calcado.forma.rotulo.toLowerCase()}'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            Formato.real(calcado.preco),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: context.textStrong,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _faixa,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: context.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.textMuted.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  final Calcado calcado;
  const _Miniatura({required this.calcado});

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      Icons.straighten_rounded,
      size: 26,
      color: context.textMuted.withValues(alpha: 0.6),
    );

    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: context.isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F4F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: !calcado.temImagem
          ? fallback
          : calcado.imagemBytes != null
          ? Image.memory(
              calcado.imagemBytes!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            )
          : Image.network(
              calcado.imagemUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}
