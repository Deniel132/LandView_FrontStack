import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/calcado.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../widgets/logo_loja.dart';

/// Cria (POST) ou edita (PUT) um modelo de calçado. A própria tela chama a
/// API: se der erro, a mensagem aparece aqui e o que foi digitado é mantido.
/// Ao concluir, devolve um texto para a tela anterior mostrar em SnackBar.
class CadastroPage extends StatefulWidget {
  final Calcado? calcado;

  const CadastroPage({super.key, this.calcado});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _marcaController = TextEditingController();
  final _precoController = TextEditingController();
  final _estoqueController = TextEditingController(text: '0');
  final _imagemController = TextEditingController();

  XFile? _arquivoImagem;
  Uint8List? _imagemPreview;
  TipoCalcado _tipo = TipoCalcado.tenis;
  FormaCalcado _forma = FormaCalcado.padrao;
  final List<MedidaTamanho> _tamanhos = [];

  bool _salvando = false;
  String? _erroApi;
  String? _erroTabela;

  bool get _editando => widget.calcado != null;

  /// Preenche os campos quando a tela foi aberta para editar um calçado.
  @override
  void initState() {
    super.initState();
    final c = widget.calcado;
    if (c != null) {
      _nomeController.text = c.nome;
      _marcaController.text = c.marca;
      _precoController.text = c.preco.toStringAsFixed(2).replaceAll('.', ',');
      _estoqueController.text = c.estoque.toString();
      _imagemController.text = c.imagemUrl ?? '';
      _imagemPreview = ApiService.modoDemo ? c.imagemBytes : null;
      _tipo = c.tipo;
      _forma = c.forma;
      _tamanhos.addAll(c.tamanhos);
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _marcaController.dispose();
    _precoController.dispose();
    _estoqueController.dispose();
    _imagemController.dispose();
    super.dispose();
  }

  /// Abre o formulário de uma numeração e a inclui na tabela do calçado.
  Future<void> _adicionarTamanho() async {
    final novo = await showDialog<MedidaTamanho>(
      context: context,
      builder: (_) => const _DialogoTamanho(),
    );
    if (novo == null) return;
    setState(() {
      // Mesma numeração digitada duas vezes: a nova substitui a antiga.
      _tamanhos.removeWhere((t) => t.numeracao == novo.numeracao);
      _tamanhos.add(novo);
      _tamanhos.sort((a, b) => a.numeracao.compareTo(b.numeracao));
      _erroTabela = null;
    });
  }

  /// Abre o seletor de arquivos e mantém a foto em memória até enviá-la à API.
  Future<void> _selecionarImagem() async {
    try {
      final arquivo = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Imagens',
            extensions: ['jpg', 'jpeg', 'png', 'webp'],
            webWildCards: ['image/*'],
          ),
        ],
      );
      if (arquivo == null) return;

      final bytes = await arquivo.readAsBytes();
      if (bytes.isEmpty) {
        throw const FormatException('O arquivo selecionado está vazio.');
      }
      if (bytes.length > 5 * 1024 * 1024) {
        throw const FormatException('A foto deve ter no máximo 5 MB.');
      }
      if (!mounted) return;
      setState(() {
        _arquivoImagem = arquivo;
        _imagemPreview = bytes;
        _imagemController.clear();
        _erroApi = null;
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      _mostrarErroImagem(e.message);
    } catch (_) {
      if (!mounted) return;
      _mostrarErroImagem(
        'Não foi possível abrir o seletor de arquivos. Reinicie o app Flutter e tente novamente.',
      );
    }
  }

  /// Exibe falhas de seleção imediatamente, sem exigir que a pessoa role o formulário.
  void _mostrarErroImagem(String mensagem) {
    setState(() => _erroApi = mensagem);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }

  /// Valida os campos e envia o cadastro ou a edição à API.
  Future<void> _salvar() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    setState(() {
      _erroTabela = _tamanhos.isEmpty
          ? 'Adicione ao menos um tamanho à tabela.'
          : null;
    });
    if (!formOk || _tamanhos.isEmpty) return;

    setState(() {
      _salvando = true;
      _erroApi = null;
    });

    try {
      final imagemUrl = _arquivoImagem == null
          ? _imagemController.text.trim()
          // Sem backend, conserva a foto selecionada em memória no próprio app.
          : ApiService.modoDemo
          ? null
          : await ApiService.instance.enviarImagem(
              _imagemPreview!,
              _arquivoImagem!.name,
            );
      final calcado = Calcado(
        id: widget.calcado?.id,
        nome: _nomeController.text.trim(),
        marca: _marcaController.text.trim(),
        tipo: _tipo,
        forma: _forma,
        preco: Formato.lerNumero(_precoController.text)!,
        estoque: int.parse(_estoqueController.text),
        imagemUrl: imagemUrl,
        imagemBytes: ApiService.modoDemo ? _imagemPreview : null,
        tamanhos: List.of(_tamanhos),
      );

      if (_editando) {
        await ApiService.instance.atualizar(calcado);
      } else {
        await ApiService.instance.criar(calcado);
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        _editando
            ? '${calcado.nome} atualizado.'
            : '${calcado.nome} cadastrado.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _erroApi = e.mensagem;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar modelo' : 'Novo modelo'),
        actions: const [MarcaAppBar()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Secao(
                    titulo: 'Identificação',
                    children: [
                      TextFormField(
                        controller: _nomeController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nome do modelo',
                          hintText: 'Ex.: Mercurial Vapor 15',
                          prefixIcon: Icon(Icons.checkroom_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Informe o nome do modelo'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _marcaController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Marca',
                          hintText: 'Ex.: Nike',
                          prefixIcon: Icon(Icons.sell_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Informe a marca'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _precoController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Preço',
                          hintText: '0,00',
                          prefixText: 'R\$ ',
                          prefixIcon: Icon(Icons.attach_money_outlined),
                        ),
                        validator: (v) {
                          final n = Formato.lerNumero(v ?? '');
                          if (n == null) return 'Preço inválido';
                          if (n <= 0) return 'Deve ser maior que zero';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _estoqueController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Quantidade em estoque',
                          hintText: '0',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                        validator: (v) {
                          final quantidade = int.tryParse((v ?? '').trim());
                          if (quantidade == null) {
                            return 'Informe uma quantidade válida';
                          }
                          if (quantidade < 0) {
                            return 'O estoque não pode ser negativo';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_imagemPreview != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          child: Image.memory(
                            _imagemPreview!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              height: 120,
                              child: Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 36,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_arquivoImagem != null) ...[
                          Text(
                            _arquivoImagem!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                      OutlinedButton.icon(
                        onPressed: _salvando ? null : _selecionarImagem,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(
                          _imagemPreview == null
                              ? 'Escolher foto do dispositivo'
                              : 'Trocar foto',
                        ),
                      ),
                      if (_imagemPreview != null)
                        TextButton.icon(
                          onPressed: _salvando
                              ? null
                              : () => setState(() {
                                  _arquivoImagem = null;
                                  _imagemPreview = null;
                                }),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remover foto selecionada'),
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _imagemController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Ou informe uma URL de imagem',
                          hintText: 'https://...',
                          prefixIcon: Icon(Icons.image_outlined),
                          helperText:
                              'Opcional. A foto escolhida no dispositivo tem prioridade.',
                        ),
                        validator: (v) {
                          if (_imagemPreview != null) return null;
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return null;
                          return t.startsWith('http')
                              ? null
                              : 'Use um endereço que comece com http';
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Secao(
                    titulo: 'Características',
                    children: [
                      _Rotulo('Tipo'),
                      SegmentedButton<TipoCalcado>(
                        segments: [
                          for (final t in TipoCalcado.values)
                            ButtonSegment<TipoCalcado>(
                              value: t,
                              label: Text(t.rotulo),
                            ),
                        ],
                        selected: {_tipo},
                        onSelectionChanged: (s) =>
                            setState(() => _tipo = s.first),
                      ),
                      const SizedBox(height: 18),
                      _Rotulo('Forma (largura do calçado)'),
                      SegmentedButton<FormaCalcado>(
                        segments: [
                          for (final f in FormaCalcado.values)
                            ButtonSegment<FormaCalcado>(
                              value: f,
                              label: Text(f.rotulo),
                            ),
                        ],
                        selected: {_forma},
                        onSelectionChanged: (s) =>
                            setState(() => _forma = s.first),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _forma.descricao,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Secao(
                    titulo: 'Tabela de medidas',
                    children: [
                      Text(
                        'Comprimento interno de cada numeração, em centímetros. '
                        'É a partir dela que o tamanho ideal é calculado.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_tamanhos.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final t in _tamanhos)
                              InputChip(
                                label: Text(
                                  '${Formato.numeracao(t.numeracao)} · ${Formato.cm(t.comprimentoCm)}',
                                ),
                                onDeleted: () =>
                                    setState(() => _tamanhos.remove(t)),
                              ),
                          ],
                        ),
                      if (_erroTabela != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _erroTabela!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _adicionarTamanho,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Adicionar tamanho'),
                        ),
                      ),
                    ],
                  ),
                  if (_erroApi != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 20,
                            color: AppColors.danger,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _erroApi!,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.4,
                                color: context.textStrong,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _salvando ? null : _salvar,
                      icon: _salvando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _editando ? Icons.save_outlined : Icons.check,
                              size: 20,
                            ),
                      label: Text(
                        _salvando
                            ? 'Salvando...'
                            : (_editando
                                  ? 'Salvar alterações'
                                  : 'Cadastrar modelo'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Diálogo para uma linha da tabela. É um widget próprio para que os
/// controladores sejam descartados no `dispose()` do próprio diálogo, depois
/// da animação de fechamento (descartar logo após o `await` gera erro).
class _DialogoTamanho extends StatefulWidget {
  const _DialogoTamanho();

  @override
  State<_DialogoTamanho> createState() => _DialogoTamanhoState();
}

class _DialogoTamanhoState extends State<_DialogoTamanho> {
  final _chave = GlobalKey<FormState>();
  final _numeracaoController = TextEditingController();
  final _comprimentoController = TextEditingController();

  @override
  void dispose() {
    _numeracaoController.dispose();
    _comprimentoController.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (!(_chave.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      MedidaTamanho(
        numeracao: Formato.lerNumero(_numeracaoController.text)!,
        comprimentoCm: Formato.lerNumero(_comprimentoController.text)!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      title: const Text(
        'Novo tamanho',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      content: Form(
        key: _chave,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _numeracaoController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Numeração',
                hintText: 'Ex.: 41',
              ),
              validator: (v) {
                final n = Formato.lerNumero(v ?? '');
                if (n == null) return 'Informe a numeração';
                if (n < 20 || n > 50) return 'Entre 20 e 50';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _comprimentoController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onFieldSubmitted: (_) => _confirmar(),
              decoration: const InputDecoration(
                labelText: 'Comprimento interno',
                hintText: 'Ex.: 26,5',
                suffixText: 'cm',
              ),
              validator: (v) {
                final n = Formato.lerNumero(v ?? '');
                if (n == null) return 'Informe o comprimento';
                if (n < 15 || n > 35) return 'Entre 15 e 35 cm';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: TextStyle(color: context.textMuted)),
        ),
        TextButton(
          onPressed: _confirmar,
          child: const Text(
            'Adicionar',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _Secao extends StatelessWidget {
  final String titulo;
  final List<Widget> children;
  const _Secao({required this.titulo, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _Rotulo extends StatelessWidget {
  final String texto;
  const _Rotulo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: TextStyle(fontSize: 13, color: context.textMuted),
      ),
    );
  }
}
