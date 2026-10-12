import 'package:flutter/material.dart';
import '../models/calcado.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../widgets/pilula.dart';
import '../widgets/logo_loja.dart';
import 'cadastro_page.dart';
import 'recomendacao_page.dart';

/// Exibe os dados de um calçado e oferece ações de edição, exclusão e consulta.
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
    final quantidade = await showDialog<int>(
      context: context,
      builder: (_) => _DialogoVenda(calcado: _c),
    );
    if (quantidade == null || !mounted) return;

    setState(() => _ocupado = true);
    try {
      final venda = await ApiService.instance.registrarVenda(
        calcadoId: calcadoId,
        quantidade: quantidade,
      );
      if (!mounted) return;
      setState(() {
        _calcado = _c.copyWith(estoque: venda.estoqueAtual);
        _ocupado = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Venda registrada: $quantidade ${quantidade == 1 ? 'unidade' : 'unidades'} de ${_c.nome}.',
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

  /// A tela de edição devolve uma mensagem; repassamos para a home,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do modelo'),
        actions: [
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
                        rotulo: 'Preço',
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
                        rotulo: 'Numerações cadastradas',
                        valor: '${_c.tamanhos.length}',
                        ultima: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tabela de medidas (comprimento interno)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                if (_c.tamanhos.isEmpty)
                  Text(
                    'Este modelo ainda não tem tabela de medidas.',
                    style: TextStyle(fontSize: 13.5, color: context.textMuted),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in _c.tamanhos) _TileMedida(medida: t),
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
                    label: const Text('Recomendar tamanho'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _ocupado ? null : _editar,
                    icon: const Icon(Icons.edit_outlined, size: 19),
                    label: const Text('Editar modelo'),
                  ),
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

class _DialogoVenda extends StatefulWidget {
  final Calcado calcado;

  const _DialogoVenda({required this.calcado});

  @override
  State<_DialogoVenda> createState() => _DialogoVendaState();
}

class _DialogoVendaState extends State<_DialogoVenda> {
  int _quantidade = 1;

  @override
  Widget build(BuildContext context) {
    final calcado = widget.calcado;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      title: const Text('Registrar venda'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            calcado.nome,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${calcado.estoque} ${calcado.estoque == 1 ? 'unidade disponível' : 'unidades disponíveis'}',
            style: TextStyle(color: context.textMuted),
          ),
          const SizedBox(height: 18),
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
                width: 56,
                child: Text(
                  '$_quantidade',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_quantidade),
          child: const Text('Confirmar venda'),
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
  const _TileMedida({required this.medida});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        children: [
          Text(
            Formato.numeracao(medida.numeracao),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: context.textStrong,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            Formato.cm(medida.comprimentoCm),
            style: TextStyle(fontSize: 11.5, color: context.textMuted),
          ),
        ],
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
        children: [
          Text(
            rotulo,
            style: TextStyle(fontSize: 14, color: context.textMuted),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: destaque ? 17 : 14.5,
                fontWeight: destaque ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: destaque ? -0.3 : 0,
                color: context.textStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
