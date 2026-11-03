import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/calcado.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../widgets/logo_loja.dart';
import '../widgets/pilula.dart';
import 'cadastro_page.dart';
import 'recomendacao_page.dart';

/// Exibe os dados de um calçado e oferece ações de venda/baixa, reposição por
/// tamanho ou total, recomendação, edição e exclusão.
class DetalhePage extends StatefulWidget {
  final Calcado calcado;

  const DetalhePage({super.key, required this.calcado});

  @override
  State<DetalhePage> createState() => _DetalhePageState();
}

class _DetalhePageState extends State<DetalhePage> {
  bool _ocupado = false;
  late Calcado _calcado;

  Calcado get _c => _calcado;

  @override
  void initState() {
    super.initState();
    _calcado = widget.calcado;
  }

  void _recomendar() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RecomendacaoPage(calcado: _c)));
  }

  Future<void> _registrarVenda() async {
    if (_c.estoque == 0) return;
    final calcadoId = _c.id;
    if (calcadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Salve o produto antes de registrar uma venda.'),
        ),
      );
      return;
    }
    final resultado = await showDialog<_ResultadoVenda>(
      context: context,
      builder: (_) => _DialogoVenda(calcado: _c),
    );
    if (resultado == null || !mounted) return;

    final quantidade = resultado.quantidade;
    final numeracao = resultado.numeracao;

    setState(() => _ocupado = true);
    try {
      final venda = await ApiService.instance.registrarVenda(
        calcadoId: calcadoId,
        quantidade: quantidade,
      );
      final aposDesconto = _c
          .descontarDoTamanho(numeracao, quantidade)
          .copyWith(estoque: venda.estoqueAtual);

      // Sincroniza a grade atualizada por tamanho no banco/memória.
      Calcado atualizadoFinal = aposDesconto;
      try {
        atualizadoFinal = await ApiService.instance.atualizar(aposDesconto);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _calcado = atualizadoFinal.copyWith(estoque: venda.estoqueAtual);
        _ocupado = false;
      });
      final totalVenda = Formato.real(_c.preco * quantidade);
      final infoTam = numeracao != null
          ? ' (Tam. ${Formato.numeracao(numeracao)})'
          : '';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Venda registrada: $quantidade ${quantidade == 1 ? 'unidade' : 'unidades'}$infoTam de ${_c.nome} ($totalVenda).',
            ),
          ),
        );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  Future<void> _ajustarEstoque() async {
    if (_c.id == null) return;
    final novoEstoque = await showDialog<int>(
      context: context,
      builder: (_) => _DialogoEstoque(estoqueAtual: _c.estoque, nome: _c.nome),
    );
    if (novoEstoque == null || novoEstoque == _c.estoque || !mounted) return;

    setState(() => _ocupado = true);
    try {
      final gradeAjustada = _c.copyWith(estoque: novoEstoque).tamanhosComEstoque;
      final atualizado = await ApiService.instance.atualizar(
        _c.copyWith(estoque: novoEstoque, tamanhos: gradeAjustada),
      );
      if (!mounted) return;
      setState(() {
        _calcado = atualizado;
        _ocupado = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Estoque de ${_c.nome} atualizado para $novoEstoque ${novoEstoque == 1 ? 'unidade' : 'unidades'}.',
            ),
          ),
        );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  /// Ajusta o estoque de uma numeração específica ao tocar no card do tamanho.
  Future<void> _ajustarEstoqueTamanho(MedidaTamanho medida) async {
    if (_c.id == null || _ocupado) return;
    final qtdAtual = medida.estoque ?? 0;
    final novaQtd = await showDialog<int>(
      context: context,
      builder: (_) => _DialogoEstoque(
        estoqueAtual: qtdAtual,
        nome: '${_c.nome} · Tam. ${Formato.numeracao(medida.numeracao)}',
      ),
    );
    if (novaQtd == null || novaQtd == qtdAtual || !mounted) return;

    setState(() => _ocupado = true);
    try {
      final calcadoNovo = _c.atualizarEstoqueDoTamanho(
        medida.numeracao,
        novaQtd,
      );
      final atualizado = await ApiService.instance.atualizar(calcadoNovo);
      if (!mounted) return;
      setState(() {
        _calcado = atualizado.copyWith(
          estoque: calcadoNovo.estoque,
          tamanhos: calcadoNovo.tamanhos,
        );
        _ocupado = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Tam. ${Formato.numeracao(medida.numeracao)} atualizado para $novaQtd un. (Total: ${calcadoNovo.estoque} un.).',
            ),
          ),
        );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  /// A tela de edição devolve uma mensagem; repassamos para a tela anterior,
  /// que recarrega a lista a partir da API.
  Future<void> _editar() async {
    final resultado = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => CadastroPage(calcado: _c)),
    );
    if (resultado != null && mounted) Navigator.of(context).pop(resultado);
  }

  /// Pede confirmação antes de remover o modelo do catálogo pela API.
  Future<void> _excluir() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Excluir modelo',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Text(
          '${_c.nome} será removido do catálogo. Essa ação não pode ser desfeita.',
          style: const TextStyle(fontSize: 14.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Manter', style: TextStyle(color: ctx.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Excluir',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    setState(() => _ocupado = true);
    try {
      await ApiService.instance.excluir(_c.id!);
      if (!mounted) return;
      Navigator.of(context).pop('${_c.nome} removido do catálogo.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  Future<void> _copiarFichaEstoque() async {
    final grade = _c.tamanhosComEstoque;
    final zerados = _c.tamanhosZerados
        .map((t) => Formato.numeracao(t.numeracao))
        .join(', ');
    final mapaGrade = grade
        .map((t) => 'Tam ${Formato.numeracao(t.numeracao)}: ${t.estoque ?? 0} un.')
        .join(' | ');

    final texto = StringBuffer()
      ..writeln('📦 *Controle de Estoque · ${_c.nome}* (${_c.marca})')
      ..writeln('• Estoque total: ${_c.estoque} un. (${Formato.real(_c.valorTotalEstoque)})')
      ..writeln('• Cobertura da grade: ${_c.totalTamanhosDisponiveis} de ${grade.length} numerações ativas')
      ..writeln('• Distribuição por tamanho: $mapaGrade');
    if (zerados.isNotEmpty) {
      texto.writeln('• ⚠️ Repor numerações esgotadas: $zerados');
    }

    await Clipboard.setData(ClipboardData(text: texto.toString().trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Ficha de estoque e reposição copiada para a área de transferência!'),
        ),
      );
  }

  Widget _pilulaStatusEstoque(BuildContext context) {
    if (_c.esgotado) {
      return const Pilula(
        texto: 'Esgotado',
        cor: AppColors.danger,
        icone: Icons.block_rounded,
      );
    }
    if (_c.estoqueBaixo) {
      return const Pilula(
        texto: 'Estoque baixo',
        cor: AppColors.hazard,
        icone: Icons.warning_amber_rounded,
      );
    }
    if (_c.estoqueAlto) {
      return Pilula(texto: 'Estoque elevado', cor: context.info);
    }
    return Pilula(texto: 'Disponível', cor: context.success);
  }

  @override
  Widget build(BuildContext context) {
    final gradeComEstoque = _c.tamanhosComEstoque;
    final zerados = _c.tamanhosZerados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do modelo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy_rounded, size: 20),
            tooltip: 'Copiar ficha de estoque',
            onPressed: _ocupado ? null : _copiarFichaEstoque,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 21),
            tooltip: 'Editar modelo',
            onPressed: _ocupado ? null : _editar,
          ),
          const MarcaAppBar(),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Imagem(calcado: _c),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Pilula(texto: _c.tipo.rotulo, destaque: true),
                    Pilula(texto: 'Forma ${_c.forma.rotulo.toLowerCase()}'),
                    _pilulaStatusEstoque(context),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _c.nome,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    height: 1.15,
                    color: context.textStrong,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _c.marca,
                  style: TextStyle(fontSize: 15, color: context.textMuted),
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: context.cardSurface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: context.hairline),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _LinhaFicha(
                        rotulo: 'Preço unitário',
                        valor: Formato.real(_c.preco),
                        destaque: true,
                      ),
                      _LinhaFicha(rotulo: 'Forma', valor: _c.forma.descricao),
                      _LinhaFicha(
                        rotulo: 'Estoque disponível',
                        valor:
                            '${_c.estoque} ${_c.estoque == 1 ? 'unidade' : 'unidades'}',
                      ),
                      _LinhaFicha(
                        rotulo: 'Valor total em estoque',
                        valor: Formato.real(_c.valorTotalEstoque),
                      ),
                      _LinhaFicha(
                        rotulo: 'Cobertura da grade',
                        valor:
                            '${_c.totalTamanhosDisponiveis} de ${gradeComEstoque.length} numerações c/ estoque',
                        ultima: zerados.isEmpty,
                      ),
                      if (zerados.isNotEmpty)
                        _LinhaFicha(
                          rotulo: 'Numerações esgotadas',
                          valor: zerados
                              .map((t) => Formato.numeracao(t.numeracao))
                              .join(', '),
                          ultima: true,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Estoque por tamanho e medidas',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                      ),
                    ),
                    Text(
                      'Toque no tamanho p/ ajustar',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (gradeComEstoque.isEmpty)
                  Text(
                    'Este modelo ainda não tem tabela de medidas.',
                    style: TextStyle(fontSize: 13.5, color: context.textMuted),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in gradeComEstoque)
                        _TileMedida(
                          medida: t,
                          onTap: () => _ajustarEstoqueTamanho(t),
                        ),
                    ],
                  ),
                const SizedBox(height: 26),
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _ocupado || _c.estoque == 0
                        ? null
                        : _registrarVenda,
                    icon: _ocupado
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.point_of_sale_outlined, size: 20),
                    label: Text(
                      _c.estoque == 0
                          ? 'Sem estoque para vender'
                          : 'Registrar venda',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _ocupado ? null : _recomendar,
                    icon: const Icon(Icons.straighten_rounded, size: 20),
                    label: const Text('Recomendar tamanho (Provador)'),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _ocupado ? null : _ajustarEstoque,
                          icon: const Icon(
                            Icons.inventory_2_outlined,
                            size: 19,
                          ),
                          label: const Text('Ajustar estoque'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _ocupado ? null : _editar,
                          icon: const Icon(Icons.edit_outlined, size: 19),
                          label: const Text('Editar modelo'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _ocupado ? null : _excluir,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(
                        color: AppColors.danger.withValues(alpha: 0.4),
                      ),
                    ),
                    icon: _ocupado
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline, size: 19),
                    label: Text(_ocupado ? 'Excluindo...' : 'Excluir modelo'),
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

class _ResultadoVenda {
  final int quantidade;
  final double? numeracao;

  const _ResultadoVenda({required this.quantidade, this.numeracao});
}

class _DialogoVenda extends StatefulWidget {
  final Calcado calcado;

  const _DialogoVenda({required this.calcado});

  @override
  State<_DialogoVenda> createState() => _DialogoVendaState();
}

class _DialogoVendaState extends State<_DialogoVenda> {
  int _quantidade = 1;
  double? _numeracaoSelecionada;

  @override
  void initState() {
    super.initState();
    final disponiveis = widget.calcado.tamanhosComEstoque
        .where((t) => (t.estoque ?? 0) > 0)
        .toList();
    if (disponiveis.isNotEmpty) {
      _numeracaoSelecionada = disponiveis.first.numeracao;
    }
  }

  @override
  Widget build(BuildContext context) {
    final calcado = widget.calcado;
    final grade = calcado.tamanhosComEstoque;
    final total = calcado.preco * _quantidade;
    final atalhos = [1, 2, 3, 5].where((q) => q <= calcado.estoque).toList();

    return AlertDialog(
      title: const Text('Registrar venda'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              calcado.nome,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              '${calcado.estoque} ${calcado.estoque == 1 ? 'unidade disponível' : 'unidades disponíveis'} · ${Formato.real(calcado.preco)} / un.',
              style: TextStyle(color: context.textMuted, fontSize: 13),
            ),
            if (grade.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Numeração da saída:',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in grade)
                    ChoiceChip(
                      label: Text(
                        '${Formato.numeracao(t.numeracao)} (${t.estoque ?? 0})',
                      ),
                      selected: _numeracaoSelecionada == t.numeracao,
                      showCheckmark: false,
                      onSelected: (t.estoque ?? 0) > 0
                          ? (_) => setState(
                              () => _numeracaoSelecionada = t.numeracao,
                            )
                          : null,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Diminuir quantidade',
                  onPressed: _quantidade > 1
                      ? () => setState(() => _quantidade--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '$_quantidade',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Aumentar quantidade',
                  onPressed: _quantidade < calcado.estoque
                      ? () => setState(() => _quantidade++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (atalhos.length > 1) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                children: [
                  for (final q in atalhos)
                    ChoiceChip(
                      label: Text('$q un.'),
                      selected: _quantidade == q,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _quantidade = q),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.subtleSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.hairline),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total da venda',
                    style: TextStyle(fontSize: 13, color: context.textMuted),
                  ),
                  Text(
                    Formato.real(total),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.textStrong,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(
            _ResultadoVenda(
              quantidade: _quantidade,
              numeracao: _numeracaoSelecionada,
            ),
          ),
          child: const Text('Confirmar venda'),
        ),
      ],
    );
  }
}

class _DialogoEstoque extends StatefulWidget {
  final int estoqueAtual;
  final String nome;

  const _DialogoEstoque({required this.estoqueAtual, required this.nome});

  @override
  State<_DialogoEstoque> createState() => _DialogoEstoqueState();
}

class _DialogoEstoqueState extends State<_DialogoEstoque> {
  late final _controller = TextEditingController(
    text: widget.estoqueAtual.toString(),
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _somar(int delta) {
    final atual = int.tryParse(_controller.text) ?? widget.estoqueAtual;
    final novo = (atual + delta).clamp(0, 9999);
    setState(() => _controller.text = novo.toString());
  }

  void _confirmar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(int.parse(_controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajustar estoque'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.nome,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onFieldSubmitted: (_) => _confirmar(),
              decoration: const InputDecoration(
                labelText: 'Nova quantidade em estoque',
                suffixText: 'un.',
              ),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n < 0) return 'Quantidade inválida';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('-1 un.'),
                  onPressed: () => _somar(-1),
                ),
                ActionChip(
                  label: const Text('+1 un.'),
                  onPressed: () => _somar(1),
                ),
                ActionChip(
                  label: const Text('+5 un.'),
                  onPressed: () => _somar(5),
                ),
                ActionChip(
                  label: const Text('+10 un.'),
                  onPressed: () => _somar(10),
                ),
                ActionChip(
                  label: const Text('Zerar'),
                  onPressed: () => setState(() => _controller.text = '0'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _confirmar,
          child: const Text('Salvar estoque'),
        ),
      ],
    );
  }
}

class _Imagem extends StatelessWidget {
  final Calcado calcado;
  const _Imagem({required this.calcado});

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      Icons.straighten_rounded,
      size: 56,
      color: context.textMuted.withValues(alpha: 0.5),
    );

    return Container(
      decoration: BoxDecoration(
        color: context.isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: context.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: !calcado.temImagem
            ? fallback
            : calcado.imagemBytes != null
            ? Image.memory(
                calcado.imagemBytes!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => fallback,
              )
            : Image.network(
                calcado.imagemUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class _TileMedida extends StatelessWidget {
  final MedidaTamanho medida;
  final VoidCallback? onTap;

  const _TileMedida({required this.medida, this.onTap});

  @override
  Widget build(BuildContext context) {
    final qtd = medida.estoque ?? 0;
    final corQtd = qtd == 0
        ? AppColors.danger
        : qtd == 1
        ? AppColors.hazard
        : context.success;

    return Material(
      color: context.cardSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: qtd == 0
                  ? AppColors.danger.withValues(alpha: 0.35)
                  : context.hairline,
            ),
          ),
          child: Column(
            children: [
              Text(
                Formato.numeracao(medida.numeracao),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: qtd == 0 ? context.textMuted : context.textStrong,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                Formato.cm(medida.comprimentoCm),
                style: TextStyle(fontSize: 11, color: context.textMuted),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: corQtd.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  qtd == 0 ? '0 un.' : '$qtd un.',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: corQtd,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinhaFicha extends StatelessWidget {
  final String rotulo;
  final String valor;
  final bool destaque;
  final bool ultima;

  const _LinhaFicha({
    required this.rotulo,
    required this.valor,
    this.destaque = false,
    this.ultima = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        border: ultima
            ? null
            : Border(bottom: BorderSide(color: context.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            rotulo,
            style: TextStyle(fontSize: 13.5, color: context.textMuted),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: destaque ? 16 : 14,
                fontWeight: destaque ? FontWeight.w700 : FontWeight.w500,
                color: destaque ? context.accent : context.textStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
