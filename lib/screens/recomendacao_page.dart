import 'package:flutter/material.dart';
import '../models/calcado.dart';
import '../models/recomendacao.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../widgets/pilula.dart';
import '../widgets/logo_loja.dart';

/// Fluxo principal do vendedor: informa a medida do pé e a numeração que o
/// cliente costuma usar. O cálculo NÃO é feito aqui: o app envia os dados
/// para a API, o Python calcula e o resultado volta para ser exibido.
class RecomendacaoPage extends StatefulWidget {
  final Calcado calcado;

  const RecomendacaoPage({super.key, required this.calcado});

  @override
  State<RecomendacaoPage> createState() => _RecomendacaoPageState();
}

class _RecomendacaoPageState extends State<RecomendacaoPage> {
  final _formKey = GlobalKey<FormState>();
  final _peController = TextEditingController();
  final _numeracaoController = TextEditingController();
  final _marcaController = TextEditingController();

  bool _calculando = false;
  String? _erro;
  Recomendacao? _resultado;

  @override
  void dispose() {
    _peController.dispose();
    _numeracaoController.dispose();
    _marcaController.dispose();
    super.dispose();
  }

  /// Valida as medidas e pede à API Python que calcule a recomendação.
  Future<void> _calcular() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final marca = _marcaController.text.trim();
    setState(() {
      _calculando = true;
      _erro = null;
      _resultado = null;
    });

    try {
      final r = await ApiService.instance.recomendar(
        calcadoId: widget.calcado.id!,
        medidaPeCm: Formato.lerNumero(_peController.text)!,
        numeracaoHabitual: Formato.lerNumero(_numeracaoController.text),
        marcaHabitual: marca.isEmpty ? null : marca,
      );
      if (!mounted) return;
      setState(() {
        _resultado = r;
        _calculando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.mensagem;
        _calculando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.calcado;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recomendar tamanho'),
        actions: const [MarcaAppBar()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Contexto: para qual modelo o cálculo está sendo feito.
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.cardSurface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: context.hairline),
                  ),
                  child: Row(
                    children: [
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
                            Text(c.marca, style: TextStyle(fontSize: 13, color: context.textMuted)),
                          ],
                        ),
                      ),
                      Pilula(texto: 'Forma ${c.forma.rotulo.toLowerCase()}', destaque: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Resultado: fica acima do formulário para continuar visível
                // quando o vendedor ajusta a medida e calcula de novo.
                if (_calculando)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_erro != null) _FaixaErro(mensagem: _erro!),
                if (_resultado != null) _PainelResultado(calcado: c, resultado: _resultado!),
                if (_resultado != null || _erro != null) const SizedBox(height: 16),

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
                        TextFormField(
                          controller: _peController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Medida do pé',
                            hintText: 'Ex.: 26,2',
                            suffixText: 'cm',
                            prefixIcon: Icon(Icons.straighten_rounded),
                          ),
                          validator: (v) {
                            final n = Formato.lerNumero(v ?? '');
                            if (n == null) return 'Informe a medida em centímetros';
                            if (n < 15 || n > 35) return 'Use um valor entre 15 e 35 cm';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _numeracaoController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Numeração que o cliente costuma usar',
                            hintText: 'Ex.: 41 (opcional)',
                            prefixIcon: Icon(Icons.confirmation_number_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = Formato.lerNumero(v);
                            if (n == null || n < 20 || n > 50) return 'Use uma numeração entre 20 e 50';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
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
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _calculando ? null : _calcular,
                    icon: _calculando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 20),
                    label: Text(_calculando ? 'Calculando...' : 'Calcular tamanho ideal'),
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

/// Painel escuro com o número recomendado em destaque.
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
          Container(height: 3, color: AppColors.brand),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tamanho recomendado',
                  style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.55)),
                ),
                const SizedBox(height: 4),
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
                Text(
                  'para ${calcado.nome}',
                  style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: 0.6)),
                ),
                if (resultado.alternativa != null || resultado.folgaCm != null) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (resultado.alternativa != null)
                        _PilulaClara(texto: 'Alternativa: ${Formato.numeracao(resultado.alternativa!)}'),
                      if (resultado.folgaCm != null)
                        _PilulaClara(texto: 'Folga: ${Formato.cm(resultado.folgaCm!)}'),
                    ],
                  ),
                ],
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
      ),
    );
  }
}

class _FaixaErro extends StatelessWidget {
  final String mensagem;
  const _FaixaErro({required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 20, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensagem,
              style: TextStyle(fontSize: 13.5, height: 1.4, color: context.textStrong),
            ),
          ),
        ],
      ),
    );
  }
}
