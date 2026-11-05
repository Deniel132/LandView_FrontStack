// Importa o seletor de arquivos multiplataforma (web e desktop)
import 'package:file_selector/file_selector.dart';
// Importa os componentes gráficos do Flutter
import 'package:flutter/material.dart';
// Importa formatadores de entrada de texto e números
import 'package:flutter/services.dart';
// Importa o modelo de calçado e medidas de tamanho
import '../models/calcado.dart';
// Importa o cliente de API para criar ou atualizar produtos
import '../services/api_service.dart';
// Importa a camada de dados de demonstração para gerar grade padrão
import '../services/dados_demo.dart';
// Importa as configurações visuais de tema
import '../theme/app_theme.dart';
// Importa utilitários de formatação de moeda e medidas
import '../utils/formato.dart';
// Importa faixas visuais de aviso e erro
import '../widgets/estados.dart';
// Importa o botão de perfil da AppBar
import '../widgets/logo_loja.dart';

/// Tela de Formulário para Criação (POST) ou Edição (PUT) de um modelo de calçado.
/// Permite cadastrar nome, marca, preço, estoque, selecionar foto local ou URL,
/// definir tipo (tênis/chuteira), largura da forma e gerenciar a grade completa de tamanhos com estoques individuais.
class CadastroPage extends StatefulWidget {
  /// Calçado a ser editado (caso nulo, opera em modo de criação de novo produto)
  final Calcado? calcado;

  /// Construtor com calçado opcional
  const CadastroPage({super.key, this.calcado});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  // Chave global de controle do formulário
  final _formKey = GlobalKey<FormState>();

  // Controlador do campo de nome do calçado
  final _nomeController = TextEditingController();

  // Controlador do campo de marca fabricante
  final _marcaController = TextEditingController();

  // Controlador do campo de preço de venda
  final _precoController = TextEditingController();

  // Controlador do campo de estoque total consolidado
  final _estoqueController = TextEditingController(text: '0');

  // Controlador do campo opcional de URL externa da imagem
  final _imagemController = TextEditingController();

  // Armazena o arquivo de foto selecionado no dispositivo
  XFile? _arquivoImagem;

  // Armazena os bytes brutos da foto para pré-visualização instantânea na tela
  Uint8List? _imagemPreview;

  // Categoria esportiva selecionada (Tênis ou Chuteira)
  TipoCalcado _tipo = TipoCalcado.tenis;

  // Formato da forma selecionado (Estreita, Padrão ou Larga)
  FormaCalcado _forma = FormaCalcado.padrao;

  // Lista dinâmica com a grade de tamanhos e seus respectivos estoques individuais
  final List<MedidaTamanho> _tamanhos = [];

  // Flag indicadora de processo de salvamento em andamento
  bool _salvando = false;

  // Mensagem de erro retornada pela API
  String? _erroApi;

  // Mensagem de validação da tabela de tamanhos
  String? _erroTabela;

  // Flag indicadora se estamos editando um produto existente ou criando um novo
  bool get _editando => widget.calcado != null;

  @override
  void initState() {
    super.initState();
    // Se estiver em modo de edição, pré-popula todos os campos com os dados do calçado
    final c = widget.calcado;
    if (c != null) {
      _nomeController.text = c.nome;
      _marcaController.text = c.marca;
      _precoController.text = c.preco.toStringAsFixed(2).replaceAll('.', ',');
      _estoqueController.text = c.estoque.toString();
      _imagemController.text =
          (c.imagemUrl != null && !c.imagemUrl!.startsWith('data:image'))
          ? c.imagemUrl!
          : '';
      _imagemPreview = c.imagemBytes;
      _tipo = c.tipo;
      _forma = c.forma;
      _tamanhos.addAll(c.tamanhosComEstoque);
    }
  }

  @override
  void dispose() {
    // Libera a memória ocupada por todos os controladores ao fechar a tela
    _nomeController.dispose();
    _marcaController.dispose();
    _precoController.dispose();
    _estoqueController.dispose();
    _imagemController.dispose();
    super.dispose();
  }

  /// Abre a janela de diálogo para adicionar um novo tamanho ou alterar a medida e o estoque de um tamanho existente
  Future<void> _editarOuAdicionarTamanho([MedidaTamanho? inicial]) async {
    // Exibe o diálogo modal e aguarda o objeto retornado
    final novo = await showDialog<MedidaTamanho>(
      context: context,
      builder: (_) => _DialogoTamanho(inicial: inicial),
    );
    if (novo == null) return;
    setState(() {
      if (inicial != null) {
        _tamanhos.remove(inicial);
      }
      // Se a numeração já existia na lista, remove a anterior para substituir pela nova
      _tamanhos.removeWhere((t) => t.numeracao == novo.numeracao);
      _tamanhos.add(novo);
      // Mantém a tabela sempre em ordem crescente de numeração
      _tamanhos.sort((a, b) => a.numeracao.compareTo(b.numeracao));

      // Se a grade tiver estoques individuais, recalcula a soma e atualiza o campo de estoque geral
      if (_tamanhos.any((t) => t.estoque != null)) {
        final soma = _tamanhos.fold<int>(0, (s, t) => s + (t.estoque ?? 0));
        _estoqueController.text = soma.toString();
      }
      _erroTabela = null;
    });
  }

  /// Gera e preenche automaticamente a grade do tamanho 37 ao 45 baseada na forma selecionada
  void _gerarGradePadrao() {
    setState(() {
      final estoqueAtual = int.tryParse(_estoqueController.text.trim()) ?? 18;
      final padrao = DadosDemo.gerarTabelaPadrao(_forma);
      for (final item in padrao) {
        if (!_tamanhos.any((t) => t.numeracao == item.numeracao)) {
          _tamanhos.add(item);
        }
      }
      _tamanhos.sort((a, b) => a.numeracao.compareTo(b.numeracao));
      final base = estoqueAtual ~/ _tamanhos.length;
      final resto = estoqueAtual % _tamanhos.length;
      for (var i = 0; i < _tamanhos.length; i++) {
        _tamanhos[i] = _tamanhos[i].copyWith(
          estoque: _tamanhos[i].estoque ?? (base + (i < resto ? 1 : 0)),
        );
      }
      final soma = _tamanhos.fold<int>(0, (s, t) => s + (t.estoque ?? 0));
      _estoqueController.text = soma.toString();
      _erroTabela = null;
    });
  }

  /// Abre a janela do explorador de arquivos para escolher uma foto no computador ou celular
  Future<void> _selecionarImagem() async {
    try {
      // Abre o seletor nativo de arquivos filtrando por extensões de imagem
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

      // Lê os bytes brutos do arquivo selecionado
      final bytes = await arquivo.readAsBytes();
      if (bytes.isEmpty) {
        throw const FormatException('O arquivo selecionado está vazio.');
      }
      // Valida limite máximo de 5MB por foto
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

  /// Exibe erros ocorridos durante a seleção de imagens
  void _mostrarErroImagem(String mensagem) {
    setState(() => _erroApi = mensagem);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }

  /// Valida todas as seções e salva o calçado na API
  Future<void> _salvar() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    setState(() {
      _erroTabela = _tamanhos.isEmpty
          ? 'Adicione ao menos um tamanho à tabela.'
          : null;
    });
    // Se houver erro de validação ou a tabela estiver vazia, interrompe o envio
    if (!formOk || _tamanhos.isEmpty) return;

    setState(() {
      _salvando = true;
      _erroApi = null;
    });

    try {
      // Processa a URL da imagem ou envia a foto selecionada
      final imagemUrl = _arquivoImagem == null
          ? (_imagemController.text.trim().isNotEmpty
                ? _imagemController.text.trim()
                : (_imagemPreview != null ? widget.calcado?.imagemUrl : null))
          : ApiService.modoDemo
          ? null
          : await ApiService.instance.enviarImagem(
              _imagemPreview!,
              _arquivoImagem!.name,
            );

      // Monta o objeto de Calçado com todos os dados validados do formulário
      final calcado = Calcado(
        id: widget.calcado?.id,
        nome: _nomeController.text.trim(),
        marca: _marcaController.text.trim(),
        tipo: _tipo,
        forma: _forma,
        preco: Formato.lerNumero(_precoController.text)!,
        estoque: int.parse(_estoqueController.text),
        imagemUrl: imagemUrl,
        imagemBytes: _imagemPreview,
        tamanhos: List.of(_tamanhos),
      );

      // Dispara criação ou atualização na API
      if (_editando) {
        await ApiService.instance.atualizar(calcado);
      } else {
        await ApiService.instance.criar(calcado);
      }
      if (!mounted) return;

      // Fecha a tela e retorna mensagem de sucesso para a tela anterior
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
                  // Seção 1: Identificação do calçado
                  _Secao(
                    titulo: 'Identificação',
                    children: [
                      // Nome do modelo
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
                      // Marca
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
                      // Preço unitário em Reais
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
                      // Estoque total
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
                      // Pré-visualização da imagem se houver bytes carregados
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
                      // Botão para selecionar foto do dispositivo
                      OutlinedButton.icon(
                        onPressed: _salvando ? null : _selecionarImagem,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(
                          _imagemPreview == null
                              ? 'Escolher foto do dispositivo'
                              : 'Trocar foto',
                        ),
                      ),
                      // Opção para remover a foto selecionada
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
                      // Campo alternativo para URL externa de imagem
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
                  // Seção 2: Características de Tipo e Forma
                  _Secao(
                    titulo: 'Características',
                    children: [
                      const _Rotulo('Tipo'),
                      // Seletor segmentado entre Tênis e Chuteira
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
                      const _Rotulo('Forma (largura do calçado)'),
                      // Seletor segmentado entre Estreita, Padrão e Larga
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
                      // Explicação textual da forma selecionada
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
                  // Seção 3: Tabela de Medidas e Estoque por Tamanho
                  _Secao(
                    titulo: 'Tabela de medidas (${_tamanhos.length})',
                    children: [
                      Text(
                        'Comprimento interno de cada numeração, em centímetros. '
                        'Toque em um tamanho para editar sua medida e estoque.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Chips com os tamanhos cadastrados na grade
                      if (_tamanhos.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final t in _tamanhos)
                              InputChip(
                                label: Text(
                                  '${Formato.numeracao(t.numeracao)} · ${Formato.cm(t.comprimentoCm)}${t.estoque != null ? ' · ${t.estoque} un.' : ''}',
                                ),
                                onPressed: () => _editarOuAdicionarTamanho(t),
                                onDeleted: () => setState(() {
                                  _tamanhos.remove(t);
                                  if (_tamanhos.any((x) => x.estoque != null)) {
                                    final soma = _tamanhos.fold<int>(
                                      0,
                                      (s, x) => s + (x.estoque ?? 0),
                                    );
                                    _estoqueController.text = soma.toString();
                                  }
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Aviso de erro caso a grade esteja vazia
                      if (_erroTabela != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            _erroTabela!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                      // Botões de ação da tabela de medidas
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Botão para adicionar tamanho avulso
                          OutlinedButton.icon(
                            onPressed: () => _editarOuAdicionarTamanho(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Adicionar tamanho'),
                          ),
                          // Botão de preenchimento inteligente da grade 37–45
                          OutlinedButton.icon(
                            onPressed: _gerarGradePadrao,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                            ),
                            icon: const Icon(
                              Icons.auto_fix_high_rounded,
                              size: 18,
                            ),
                            label: const Text('Preencher grade 37–45'),
                          ),
                          // Opção para limpar toda a tabela
                          if (_tamanhos.length > 1)
                            TextButton(
                              onPressed: () =>
                                  setState(() => _tamanhos.clear()),
                              child: const Text(
                                'Limpar tabela',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  // Faixa de erro da API
                  if (_erroApi != null) ...[
                    const SizedBox(height: 16),
                    FaixaAviso.erro(mensagem: _erroApi!),
                  ],
                  const SizedBox(height: 22),
                  // Botão principal de salvar modelo
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

/// Diálogo modal para adicionar ou editar uma medida de tamanho e sua quantidade em estoque
class _DialogoTamanho extends StatefulWidget {
  final MedidaTamanho? inicial;
  const _DialogoTamanho({this.inicial});

  @override
  State<_DialogoTamanho> createState() => _DialogoTamanhoState();
}

class _DialogoTamanhoState extends State<_DialogoTamanho> {
  final _chave = GlobalKey<FormState>();
  late final _numeracaoController = TextEditingController(
    text: widget.inicial == null
        ? ''
        : Formato.numeracao(widget.inicial!.numeracao),
  );
  late final _comprimentoController = TextEditingController(
    text: widget.inicial == null
        ? ''
        : widget.inicial!.comprimentoCm.toStringAsFixed(1).replaceAll('.', ','),
  );
  late final _estoqueTamanhoController = TextEditingController(
    text: widget.inicial?.estoque?.toString() ?? '2',
  );

  @override
  void dispose() {
    _numeracaoController.dispose();
    _comprimentoController.dispose();
    _estoqueTamanhoController.dispose();
    super.dispose();
  }

  /// Confirma e valida a numeração inserida
  void _confirmar() {
    if (!(_chave.currentState?.validate() ?? false)) return;
    final qtdTexto = _estoqueTamanhoController.text.trim();
    final qtd = qtdTexto.isEmpty ? null : int.tryParse(qtdTexto);
    Navigator.of(context).pop(
      MedidaTamanho(
        numeracao: Formato.lerNumero(_numeracaoController.text)!,
        comprimentoCm: Formato.lerNumero(_comprimentoController.text)!,
        estoque: qtd,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.inicial != null;
    return AlertDialog(
      title: Text(
        editando ? 'Editar tamanho' : 'Novo tamanho',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      content: Form(
        key: _chave,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Numeração
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
            // Comprimento interno
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
            const SizedBox(height: 14),
            // Estoque individual deste tamanho
            TextFormField(
              controller: _estoqueTamanhoController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onFieldSubmitted: (_) => _confirmar(),
              decoration: const InputDecoration(
                labelText: 'Estoque deste tamanho',
                hintText: 'Ex.: 3',
                suffixText: 'un.',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = int.tryParse(v.trim());
                if (n == null || n < 0) return 'Quantidade inválida';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        // Cancelar
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: TextStyle(color: context.textMuted)),
        ),
        // Confirmar (Adicionar ou Salvar)
        TextButton(
          onPressed: _confirmar,
          child: Text(
            editando ? 'Salvar' : 'Adicionar',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Contêiner de seção estilizado com título
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

/// Rótulo auxiliar para campos de formulário
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
