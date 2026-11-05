// Importa os componentes e estilos visuais do Flutter
import 'package:flutter/material.dart';
// Importa o Clipboard para permitir a cópia do resultado da recomendação para a área de transferência
import 'package:flutter/services.dart';
// Importa o modelo do calçado
import '../models/calcado.dart';
// Importa o modelo de recomendação retornado pela API ou algoritmo
import '../models/recomendacao.dart';
// Importa o serviço de API para chamar o cálculo de provador virtual
import '../services/api_service.dart';
// Importa o tema e as cores do aplicativo
import '../theme/app_theme.dart';
// Importa formatadores de numeração e centímetros
import '../utils/formato.dart';
// Importa faixas visuais de erro e aviso
import '../widgets/estados.dart';
// Importa o botão de perfil do atendente da AppBar
import '../widgets/logo_loja.dart';
// Importa as tags visuais em formato de pílula
import '../widgets/pilula.dart';

/// Tela do Provador Virtual: permite ao vendedor inserir o comprimento do pé do cliente em centímetros
/// e opcionalmente a numeração habitual que ele calça em outras marcas.
/// O sistema processa a recomendação considerando o tipo (tênis/chuteira) e o formato da forma (estreita, padrão, larga),
/// destacando visualmente o tamanho sugerido na grade do calçado.
class RecomendacaoPage extends StatefulWidget {
  /// Calçado sobre o qual a recomendação de tamanho será calculada
  final Calcado calcado;

  /// Construtor com calçado obrigatório
  const RecomendacaoPage({super.key, required this.calcado});

  @override
  State<RecomendacaoPage> createState() => _RecomendacaoPageState();
}

class _RecomendacaoPageState extends State<RecomendacaoPage> {
  // Chave de controle e validação do formulário de medidas
  final _formKey = GlobalKey<FormState>();

  // Controlador do campo de medida do pé em centímetros
  final _peController = TextEditingController();

  // Controlador do campo opcional de numeração habitual do cliente
  final _numeracaoController = TextEditingController();

  // Controlador do campo opcional da marca dessa numeração habitual
  final _marcaController = TextEditingController();

  // Flag indicadora de cálculo em andamento
  bool _calculando = false;

  // Mensagem de erro caso a validação ou requisição falhe
  String? _erro;

  // Objeto com o resultado da recomendação retornada
  Recomendacao? _resultado;

  @override
  void dispose() {
    // Libera a memória ocupada pelos controladores de texto ao fechar a tela
    _peController.dispose();
    _numeracaoController.dispose();
    _marcaController.dispose();
    super.dispose();
  }

  /// Dispara o cálculo do tamanho ideal via API ou algoritmo local
  Future<void> _calcular() async {
    // Valida se os campos foram preenchidos corretamente
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Fecha o teclado virtual
    FocusScope.of(context).unfocus();

    // Obtém a marca habitual informada (opcional)
    final marca = _marcaController.text.trim();

    // Atualiza o estado para exibir o indicador de progresso
    setState(() {
      _calculando = true;
      _erro = null;
      _resultado = null;
    });

    try {
      // Chama o endpoint de recomendação passando o ID do calçado, medida do pé e parâmetros habituais
      final r = await ApiService.instance.recomendar(
        calcadoId: widget.calcado.id!,
        medidaPeCm: Formato.lerNumero(_peController.text)!,
        numeracaoHabitual: Formato.lerNumero(_numeracaoController.text),
        marcaHabitual: marca.isEmpty ? null : marca,
      );

      // Garante que o componente ainda está montado antes de atualizar a UI
      if (!mounted) return;

      // Armazena o resultado obtido e encerra o loading
      setState(() {
        _resultado = r;
        _calculando = false;
      });
    } on ApiException catch (e) {
      // Captura erros de cálculo (ex: calçado sem grade cadastrada)
      if (!mounted) return;
      setState(() {
        _erro = e.mensagem;
        _calculando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calçado de referência
    final c = widget.calcado;

    // Estrutura principal da página com Scaffold
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provador · Recomendar tamanho'),
        actions: const [MarcaAppBar()],
      ),
      body: Center(
        // Centraliza e limita a largura a 560px para boa leitura visual
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          // Permite rolagem do formulário e resultados
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cartão de contexto com o modelo e a forma do calçado
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.cardSurface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: context.hairline),
                  ),
                  child: Row(
                    children: [
                      // Nome e marca do calçado
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.nome,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: context.textStrong,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${c.marca} · ${c.tipo.rotulo}',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Pílula com o tipo da forma do calçado
                      Pilula(
                        texto: 'Forma ${c.forma.rotulo.toLowerCase()}',
                        destaque: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Exibe o spinner de carregamento durante o cálculo
                if (_calculando)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                // Exibe faixa vermelha em caso de erro
                if (_erro != null) FaixaAviso.erro(mensagem: _erro!),

                // Se houver resultado calculado, exibe o painel de destaque com o número
                if (_resultado != null)
                  _PainelResultado(calcado: c, resultado: _resultado!),

                if (_resultado != null || _erro != null)
                  const SizedBox(height: 16),

                // Formulário de entrada de medidas
                Form(
                  key: _formKey,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 22),
                    decoration: BoxDecoration(
                      color: context.cardSurface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(color: context.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Campo de digitação da medida do pé em centímetros
                        TextFormField(
                          controller: _peController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Medida do pé',
                            hintText: 'Ex.: 26,2',
                            suffixText: 'cm',
                            prefixIcon: Icon(Icons.straighten_rounded),
                          ),
                          // Validação da medida do pé (espera entre 15 e 35 cm)
                          validator: (v) {
                            final n = Formato.lerNumero(v ?? '');
                            if (n == null) {
                              return 'Informe a medida em centímetros';
                            }
                            if (n < 15 || n > 35) {
                              return 'Use um valor entre 15 e 35 cm';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        // Chips de atalho rápido com medidas frequentes de pés
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final medidaRapida in const [
                              '24,5',
                              '25,5',
                              '26,5',
                              '27,5',
                              '28,5',
                            ])
                              ActionChip(
                                label: Text('$medidaRapida cm'),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  _peController.text = medidaRapida;
                                  _calcular();
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Campo opcional da numeração que o cliente costuma calçar
                        TextFormField(
                          controller: _numeracaoController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Numeração que o cliente costuma usar',
                            hintText: 'Ex.: 41 (opcional)',
                            prefixIcon: Icon(
                              Icons.confirmation_number_outlined,
                            ),
                          ),
                          // Validação da numeração habitual
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = Formato.lerNumero(v);
                            if (n == null || n < 20 || n > 50) {
                              return 'Use uma numeração entre 20 e 50';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Campo opcional da marca habitual
                        TextFormField(
                          controller: _marcaController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _calcular(),
                          decoration: const InputDecoration(
                            labelText: 'Marca dessa numeração',
                            hintText: 'Ex.: Adidas (opcional)',
                            prefixIcon: Icon(Icons.sell_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Botão de ação para calcular tamanho ideal
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _calculando ? null : _calcular,
                    icon: _calculando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 20),
                    label: Text(
                      _calculando ? 'Calculando...' : 'Calcular tamanho ideal',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Painel escuro elegante com o tamanho sugerido em tipografia grande e posição na grade de medidas
class _PainelResultado extends StatelessWidget {
  final Calcado calcado;
  final Recomendacao resultado;

  const _PainelResultado({required this.calcado, required this.resultado});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Linha decorativa azul no topo do painel
          Container(height: 3, color: AppColors.brand),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Legenda de identificação
                Text(
                  'Tamanho recomendado',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 4),
                // Numeração calculada em destaque gigante de 56px
                Text(
                  Formato.numeracao(resultado.tamanho),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -2,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                // Nome do calçado associado à recomendação
                Text(
                  'para ${calcado.nome}',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                // Pílulas com alternativa de numeração e folga real
                if (resultado.alternativa != null ||
                    resultado.folgaCm != null) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (resultado.alternativa != null)
                        _PilulaClara(
                          texto:
                              'Alternativa: ${Formato.numeracao(resultado.alternativa!)}',
                        ),
                      if (resultado.folgaCm != null)
                        _PilulaClara(
                          texto: 'Folga: ${Formato.cm(resultado.folgaCm!)}',
                        ),
                    ],
                  ),
                ],
                // Observação técnica detalhando a recomendação
                if (resultado.observacao.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    resultado.observacao,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
                // Grade completa destacando onde a numeração recomendada se posiciona
                if (calcado.tamanhos.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Posição na grade do modelo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final m in calcado.tamanhos)
                        _ChipGradeResultado(
                          medida: m,
                          recomendado: m.numeracao == resultado.tamanho,
                          alternativa: m.numeracao == resultado.alternativa,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                // Botão de cópia rápida para o vendedor enviar ao cliente pelo WhatsApp
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    onPressed: () async {
                      // Monta a mensagem formatada para WhatsApp com negritos
                      final texto = StringBuffer()
                        ..writeln('📏 *Recomendação do Provador LandView*')
                        ..writeln('• Modelo: *${calcado.nome}* (${calcado.marca})')
                        ..writeln(
                          '• Tamanho ideal: *${Formato.numeracao(resultado.tamanho)} BR*',
                        );
                      if (resultado.alternativa != null) {
                        texto.writeln(
                          '• Alternativa próxima: ${Formato.numeracao(resultado.alternativa!)} BR',
                        );
                      }
                      if (resultado.observacao.isNotEmpty) {
                        texto.writeln('• Detalhes: ${resultado.observacao}');
                      }
                      texto.writeln(
                        '• Valor: ${Formato.real(calcado.preco)} (ou ${Formato.real(calcado.preco * 0.95)} no PIX)',
                      );
                      // Copia o texto para a área de transferência do celular ou computador
                      await Clipboard.setData(
                        ClipboardData(text: texto.toString().trim()),
                      );
                      if (!context.mounted) return;
                      // Notifica o vendedor na tela
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Recomendação copiada! Pronto para enviar ao cliente.',
                            ),
                          ),
                        );
                    },
                    icon: const Icon(Icons.content_copy_rounded, size: 17),
                    label: const Text('Copiar recomendação p/ cliente'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip individual na grade de medidas do resultado destacando a numeração recomendada
class _ChipGradeResultado extends StatelessWidget {
  final MedidaTamanho medida;
  final bool recomendado;
  final bool alternativa;

  const _ChipGradeResultado({
    required this.medida,
    required this.recomendado,
    required this.alternativa,
  });

  @override
  Widget build(BuildContext context) {
    // Cor de fundo do chip (azul se recomendado, translúcido se alternativo ou padrão)
    final corFundo = recomendado
        ? AppColors.brand
        : alternativa
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.04);

    // Cor da borda
    final corBorda = recomendado
        ? AppColors.brandLight
        : alternativa
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: corBorda),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Numeração
          Text(
            Formato.numeracao(medida.numeracao),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: recomendado || alternativa
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.65),
            ),
          ),
          // Comprimento da palmilha em cm
          Text(
            Formato.cm(medida.comprimentoCm),
            style: TextStyle(
              fontSize: 10.5,
              color: recomendado
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta translúcida clara para fundo escuro do painel de resultado
class _PilulaClara extends StatelessWidget {
  final String texto;
  const _PilulaClara({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
