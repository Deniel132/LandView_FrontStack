// Importa biblioteca de conversão para decodificar base64 caso necessário
import 'dart:convert';
// Importa os componentes visuais do Flutter
import 'package:flutter/material.dart';
// Importa o modelo de dados de calçado
import '../models/calcado.dart';
// Importa as configurações visuais de tema e cores
import '../theme/app_theme.dart';
// Importa utilitários de formatação de moeda e números
import '../utils/formato.dart';
// Importa o componente visual de etiqueta (Pílula)
import 'pilula.dart';

/// Cartão de calçado exibido na listagem do catálogo de estoque,
/// contendo miniatura da foto, nome, marca, tags de categoria/forma, status de estoque e preço.
/// Ao clicar no cartão, navega para a tela com a visão detalhada do produto.
class CartaoCalcado extends StatelessWidget {
  /// Dados do calçado que serão renderizados no cartão
  final Calcado calcado;

  /// Callback de toque para abrir os detalhes do calçado
  final VoidCallback? onTap;

  /// Construtor imutável do cartão
  const CartaoCalcado({super.key, required this.calcado, this.onTap});

  /// Gera a legenda resumida da grade de tamanhos (ex: "nº 37 a 44 (6/8 tam.)")
  String get _faixa {
    // Se não houver tamanhos cadastrados, retorna aviso
    if (calcado.tamanhos.isEmpty) return 'sem tabela';
    // Menor número da grade ordenada
    final menor = calcado.tamanhos.first.numeracao;
    // Maior número da grade ordenada
    final maior = calcado.tamanhos.last.numeracao;
    // Quantidade de tamanhos que possuem unidades disponíveis no estoque
    final ativos = calcado.totalTamanhosDisponiveis;
    // Total de tamanhos contemplados na grade
    final total = calcado.tamanhos.length;
    // Retorna a descrição formatada
    return 'nº ${Formato.numeracao(menor)} a ${Formato.numeracao(maior)} ($ativos/$total tam.)';
  }

  /// Retorna a pílula colorida indicadora do status de estoque do calçado
  Widget _pilulaEstoque(BuildContext context) {
    // Caso o estoque esteja completamente zerado
    if (calcado.esgotado) {
      return const Pilula(
        texto: 'Esgotado',
        cor: AppColors.danger,
        icone: Icons.block_rounded,
      );
    }
    // Caso esteja em nível de alerta crítico (entre 1 e 5 unidades)
    if (calcado.estoqueBaixo) {
      return Pilula(
        texto: 'Restam ${calcado.estoque} un.',
        cor: AppColors.hazard,
        icone: Icons.warning_amber_rounded,
      );
    }
    // Caso possua excesso de estoque (40 unidades ou mais)
    if (calcado.estoqueAlto) {
      return Pilula(
        texto: '${calcado.estoque} un. (excesso)',
        cor: context.info,
      );
    }
    // Estoque regular saudável
    return Pilula(
      texto: '${calcado.estoque} un.',
      cor: context.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Caixa contenedora do cartão com margem inferior
    return Container(
      // Margem inferior de 12px entre os cartões
      margin: const EdgeInsets.only(bottom: 12),
      // Decoração visual do cartão
      decoration: BoxDecoration(
        // Cor de fundo do cartão
        color: context.cardSurface,
        // Bordas arredondadas com raio grande
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        // Borda fina sutil
        border: Border.all(color: context.hairline),
        // Sombra suave para efeito de elevação
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.28 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Garante que o efeito de clique não ultrapasse os cantos arredondados
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        // Área clicável com efeito de toque Material (InkWell)
        child: InkWell(
          onTap: onTap,
          // Preenchimento interno de 12px
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Miniatura da imagem ou ícone ilustrativo
                _Miniatura(calcado: calcado),
                // Espaçamento horizontal de 14px
                const SizedBox(width: 14),
                // Coluna com as informações textuais do produto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome comercial do calçado em destaque
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
                      // Espaçamento de 2px
                      const SizedBox(height: 2),
                      // Marca fabricante com cor atenuada
                      Text(
                        calcado.marca,
                        style: TextStyle(fontSize: 13, color: context.textMuted),
                      ),
                      // Espaçamento de 8px
                      const SizedBox(height: 8),
                      // Conjunto de pílulas (Tipo, Forma e Situação do Estoque)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // Pílula com o tipo esportivo (Tênis ou Chuteira)
                          Pilula(texto: calcado.tipo.rotulo, destaque: true),
                          // Pílula indicando a largura da forma
                          Pilula(
                            texto:
                                'Forma ${calcado.forma.rotulo.toLowerCase()}',
                          ),
                          // Pílula com o status de unidades em estoque
                          _pilulaEstoque(context),
                        ],
                      ),
                      // Espaçamento de 10px
                      const SizedBox(height: 10),
                      // Linha contendo o preço e a faixa de numerações disponíveis
                      Row(
                        children: [
                          // Preço formatado em Reais (R$)
                          Text(
                            Formato.real(calcado.preco),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: context.textStrong,
                            ),
                          ),
                          // Espaçamento horizontal de 10px
                          const SizedBox(width: 10),
                          // Legenda da grade de tamanhos
                          Flexible(
                            child: Text(
                              _faixa,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Ícone de seta para a direita indicando navegação
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

/// Widget auxiliar responsável por exibir a foto do calçado ou um ícone de fallback caso não haja foto.
class _Miniatura extends StatelessWidget {
  final Calcado calcado;
  const _Miniatura({required this.calcado});

  @override
  Widget build(BuildContext context) {
    // Ícone cinza ilustrativo exibido quando a foto não existir ou falhar ao carregar
    final fallback = Icon(
      Icons.straighten_rounded,
      size: 26,
      color: context.textMuted.withValues(alpha: 0.6),
    );

    // Constrói a imagem tratando tanto bytes em memória quanto URLs remotas ou Base64
    Widget construirImagem() {
      // Se não tiver imagem, exibe o fallback
      if (!calcado.temImagem) return fallback;

      // Se possuir bytes em memória RAM (modo demo ou foto selecionada)
      if (calcado.imagemBytes != null) {
        return Image.memory(
          calcado.imagemBytes!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        );
      }

      final url = calcado.imagemUrl!;
      // Se for string Base64 embutida, decodifica para Image.memory com segurança
      if (url.startsWith('data:image')) {
        final idx = url.indexOf('base64,');
        if (idx != -1) {
          try {
            final bytes = base64Decode(url.substring(idx + 7));
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            );
          } catch (_) {
            return fallback;
          }
        }
      }

      // Se for URL HTTP ou HTTPS normal, carrega da rede
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    // Contêiner quadrado de 76x76 pixels com bordas arredondadas para abrigar a imagem
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: context.isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF3F4F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: construirImagem(),
    );
  }
}
