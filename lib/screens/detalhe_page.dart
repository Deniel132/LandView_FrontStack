// Importa utilitário de conversão para decodificar imagens em base64 com segurança
import 'dart:convert';
// Importa os componentes gráficos do Flutter
import 'package:flutter/material.dart';
// Importa o Clipboard para permitir a cópia da ficha de estoque do calçado
import 'package:flutter/services.dart';
// Importa o modelo de calçado e medidas de tamanho
import '../models/calcado.dart';
// Importa o cliente de API para registrar vendas, atualizar estoque e excluir
import '../services/api_service.dart';
// Importa o gerenciador da sessão e permissões do usuário logado
import '../services/sessao.dart';
// Importa o tema e cores do aplicativo
import '../theme/app_theme.dart';
// Importa utilitários de formatação de moeda, numerações e centímetros
import '../utils/formato.dart';
// Importa o botão de perfil de usuário na AppBar
import '../widgets/logo_loja.dart';
// Importa as tags em formato de pílula
import '../widgets/pilula.dart';
// Importa a tela de formulário para edição do modelo
import 'cadastro_page.dart';
// Importa a tela do provador virtual
import 'recomendacao_page.dart';

/// Tela de Detalhes do Calçado: apresenta a foto em tamanho ampliado, características completas,
/// ficha técnica de estoque e valor total imobilizado, grade de medidas interativa (com ajuste rápido por tamanho),
/// registro de vendas com baixa de estoque, recomendação do provador virtual, edição e exclusão.
class DetalhePage extends StatefulWidget {
  /// Calçado exibido na tela
  final Calcado calcado;

  /// Construtor com calçado obrigatório
  const DetalhePage({super.key, required this.calcado});

  @override
  State<DetalhePage> createState() => _DetalhePageState();
}

class _DetalhePageState extends State<DetalhePage> {
  // Flag que indica se alguma operação assíncrona está em andamento (venda, ajuste ou exclusão)
  bool _ocupado = false;

  // Estado mutável local do calçado para atualização imediata após vendas e ajustes de estoque
  late Calcado _calcado;

  // Getter auxiliar de conveniência
  Calcado get _c => _calcado;

  @override
  void initState() {
    super.initState();
    // Inicializa o estado com o calçado passado por parâmetro
    _calcado = widget.calcado;
  }

  /// Navega para a tela do provador virtual passando o calçado atual
  void _recomendar() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RecomendacaoPage(calcado: _c)));
  }

  /// Abre o modal interativo para registrar uma venda com seleção de tamanho e quantidade
  Future<void> _registrarVenda() async {
    // Se o estoque estiver zerado, não permite registrar venda
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

    // Exibe o diálogo de venda modal
    final resultado = await showDialog<_ResultadoVenda>(
      context: context,
      builder: (_) => _DialogoVenda(calcado: _c),
    );
    if (resultado == null || !mounted) return;

    final quantidade = resultado.quantidade;
    final numeracao = resultado.numeracao;

    setState(() => _ocupado = true);
    try {
      // Dispara o registro da venda via API (baixa o estoque e cria a saída de auditoria)
      final venda = await ApiService.instance.registrarVenda(
        calcadoId: calcadoId,
        quantidade: quantidade,
      );

      // Desconta a quantidade vendida na numeração específica escolhida
      final aposDesconto = _c
          .descontarDoTamanho(numeracao, quantidade)
          .copyWith(estoque: venda.estoqueAtual);

      // Salva a nova grade detalhada no armazenamento local garantindo persistência imediata (fora do modo demo)
      if (!ApiService.modoDemo) {
        // Grava no SharedPreferences
        await Sessao.salvarGradeTamanhos(calcadoId, aposDesconto.tamanhos);
      }

      // Sincroniza a nova quantidade total no backend
      try {
        await ApiService.instance.atualizar(aposDesconto);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        // Atualiza a tela mantendo exatamente o desconto aplicado na numeração vendida
        _calcado = aposDesconto;
        _ocupado = false;
      });

      // Exibe notificação de confirmação com resumo da venda e valor monetário total
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

  /// Abre o diálogo para alterar o estoque total do modelo
  Future<void> _ajustarEstoque() async {
    if (_c.id == null) return;
    final novoEstoque = await showDialog<int>(
      context: context,
      builder: (_) => _DialogoEstoque(estoqueAtual: _c.estoque, nome: _c.nome),
    );
    if (novoEstoque == null || novoEstoque == _c.estoque || !mounted) return;

    setState(() => _ocupado = true);
    try {
      // Distribui o novo estoque total proporcionalmente na grade de tamanhos
      final gradeAjustada = _c.copyWith(estoque: novoEstoque).tamanhosComEstoque;
      // Cria a nova instância com o estoque ajustado e a grade equilibrada
      final calcadoNovo = _c.copyWith(estoque: novoEstoque, tamanhos: gradeAjustada);
      // Salva a nova grade de tamanhos no armazenamento local (fora do modo demonstração)
      if (!ApiService.modoDemo) {
        // Grava no SharedPreferences
        await Sessao.salvarGradeTamanhos(_c.id!, gradeAjustada);
      }
      // Sincroniza a alteração de estoque no backend
      final atualizado = await ApiService.instance.atualizar(calcadoNovo);
      if (!mounted) return;
      setState(() {
        // Atualiza a tela mantendo a grade equilibrada
        _calcado = calcadoNovo.copyWith(estoque: atualizado.estoque);
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

  /// Ajusta o estoque de uma numeração específica ao tocar no cartão do tamanho
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
      // Atualiza apenas a numeração clicada e recalcula a soma total
      final calcadoNovo = _c.atualizarEstoqueDoTamanho(
        medida.numeracao,
        novaQtd,
      );
      // Salva a nova grade de tamanhos no armazenamento local (fora do modo demonstração)
      if (!ApiService.modoDemo) {
        // Grava no SharedPreferences
        await Sessao.salvarGradeTamanhos(_c.id!, calcadoNovo.tamanhos);
      }
      // Sincroniza a atualização no backend
      final atualizado = await ApiService.instance.atualizar(calcadoNovo);
      if (!mounted) return;
      setState(() {
        _calcado = calcadoNovo.copyWith(
          estoque: atualizado.estoque,
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

  /// Abre a tela de edição do calçado
  Future<void> _editar() async {
    final resultado = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => CadastroPage(calcado: _c)),
    );
    if (resultado != null && mounted) Navigator.of(context).pop(resultado);
  }

  /// Pede confirmação e exclui o calçado da API
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

  /// Copia um relatório resumido da grade e situação do estoque para a área de transferência
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

  /// Retorna a pílula colorida correspondente à situação de estoque do calçado
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
    final podeGerenciar = Sessao.instance.usuario?.podeGerenciarProdutos ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do modelo'),
        actions: [
          // Botão para copiar ficha técnica de estoque
          IconButton(
            icon: const Icon(Icons.content_copy_rounded, size: 20),
            tooltip: 'Copiar ficha de estoque',
            onPressed: _ocupado ? null : _copiarFichaEstoque,
          ),
          // Botão para editar o calçado (disponível apenas para Dono/Gerente)
          if (Sessao.instance.usuario?.podeGerenciarProdutos ?? false)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 21),
              tooltip: 'Editar modelo',
              onPressed: _ocupado ? null : _editar,
            ),
          // Botão de perfil do usuário
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
                // Imagem ampliada do calçado
                _Imagem(calcado: _c),
                const SizedBox(height: 20),
                // Tags com Tipo, Forma e Status de Estoque
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
                // Nome do calçado em destaque grande
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
                // Marca
                Text(
                  _c.marca,
                  style: TextStyle(fontSize: 15, color: context.textMuted),
                ),
                const SizedBox(height: 18),
                // Cartão com a ficha técnica de preços e estoque
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
                // Cabeçalho da grade de tamanhos
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
                      podeGerenciar ? 'Toque no tamanho p/ ajustar' : 'Grade para venda',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: podeGerenciar ? context.accent : context.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Exibe os cartões de cada tamanho com suas medidas e quantidades
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
                          onTap: podeGerenciar ? () => _ajustarEstoqueTamanho(t) : null,
                        ),
                    ],
                  ),
                const SizedBox(height: 26),
                // Botão principal: Registrar Venda
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
                // Botão secundário: Recomendar tamanho (Provador)
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _ocupado ? null : _recomendar,
                    icon: const Icon(Icons.straighten_rounded, size: 20),
                    label: const Text('Recomendar tamanho (Provador)'),
                  ),
                ),
                // Ações administrativas: Ajustar Estoque, Editar Modelo e Excluir (somente para Dono/Gerente)
                if (podeGerenciar) ...[
                  const SizedBox(height: 10),
                  // Linha com Ajustar Estoque e Editar Modelo
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
                  // Botão vermelho de excluir modelo
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dados retornados pelo diálogo de confirmação de venda
class _ResultadoVenda {
  final int quantidade;
  final double? numeracao;

  const _ResultadoVenda({required this.quantidade, this.numeracao});
}

/// Diálogo modal para registrar a venda com atalhos de numeração e quantidade
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
    // Pré-seleciona a primeira numeração que tiver estoque disponível
    final disponiveis = widget.calcado.tamanhosComEstoque
        .where((t) => (t.estoque ?? 0) > 0)
        .toList();
    if (disponiveis.isNotEmpty) {
      _numeracaoSelecionada = disponiveis.first.numeracao;
      _quantidade = 1;
    } else {
      _quantidade = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Referência ao calçado recebido pelo diálogo
    final calcado = widget.calcado;
    // Obtém a grade equilibrada de tamanhos e estoques
    final grade = calcado.tamanhosComEstoque;

    // Obtém o estoque disponível especificamente para a numeração selecionada
    final estoqueDoTamanho = _numeracaoSelecionada != null
        ? (grade.any((t) => t.numeracao == _numeracaoSelecionada)
            ? (grade
                    .firstWhere((t) => t.numeracao == _numeracaoSelecionada)
                    .estoque ??
                0)
            : calcado.estoque)
        : calcado.estoque;

    // Limite máximo de unidades que podem ser vendidas nesta operação
    final maxPermitido = estoqueDoTamanho > 0 ? estoqueDoTamanho : 0;

    // Quantidade efetiva respeitando os limites sem mutação de estado durante o build
    final qtdEfetiva = maxPermitido == 0
        ? 0
        : _quantidade.clamp(1, maxPermitido);

    // Calcula o valor total em reais com base na quantidade válida
    final total = calcado.preco * qtdEfetiva;
    // Filtra atalhos numéricos que cabem dentro do estoque do tamanho
    final atalhos = [1, 2, 3, 5].where((q) => q <= maxPermitido).toList();

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
            // Seleção da numeração específica da saída
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
                          ? (_) => setState(() {
                              // Seleciona a numeração clicada
                              _numeracaoSelecionada = t.numeracao;
                              // Quantidade disponível neste tamanho
                              final disp = t.estoque ?? 0;
                              // Ajusta a quantidade caso ultrapasse o limite do novo tamanho
                              if (_quantidade > disp) {
                                _quantidade = disp > 0 ? disp : 1;
                              } else if (_quantidade < 1 && disp > 0) {
                                _quantidade = 1;
                              }
                            })
                          : null,
                    ),
                ],
              ),
              // Informa o saldo disponível exclusivamente no tamanho selecionado
              if (_numeracaoSelecionada != null) ...[
                const SizedBox(height: 6),
                Text(
                  maxPermitido > 0
                      ? 'Disponível no Tam. ${Formato.numeracao(_numeracaoSelecionada!)}: $maxPermitido ${maxPermitido == 1 ? 'unidade' : 'unidades'}'
                      : 'Tam. ${Formato.numeracao(_numeracaoSelecionada!)} sem estoque disponível',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: maxPermitido > 0
                        ? const Color(0xFF10B981)
                        : Colors.redAccent,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
            // Controle numérico com botões de aumentar e diminuir quantidade
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Diminuir quantidade',
                  onPressed: qtdEfetiva > 1
                      ? () => setState(() => _quantidade = qtdEfetiva - 1)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '$qtdEfetiva',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: maxPermitido == 0 ? Colors.redAccent : null,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Aumentar quantidade',
                  // Bloqueia rigorosamente o aumento quando atinge o estoque disponível do tamanho
                  onPressed: (qtdEfetiva < maxPermitido)
                      ? () => setState(() => _quantidade = qtdEfetiva + 1)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            // Chips de atalho rápido de quantidade (1, 2, 3, 5 un.)
            if (atalhos.length > 1) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                children: [
                  for (final q in atalhos)
                    ChoiceChip(
                      label: Text('$q un.'),
                      selected: qtdEfetiva == q,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _quantidade = q),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            // Resumo do valor total da venda
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
        // Cancelar
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        // Confirmar venda (bloqueado se quantidade for zero ou maior que o estoque do tamanho)
        ElevatedButton(
          onPressed: (qtdEfetiva > 0 && qtdEfetiva <= maxPermitido)
              ? () => Navigator.of(context).pop(
                  _ResultadoVenda(
                    quantidade: qtdEfetiva,
                    numeracao: _numeracaoSelecionada,
                  ),
                )
              : null,
          child: const Text('Confirmar venda'),
        ),
      ],
    );
  }
}

/// Diálogo modal para ajuste manual de quantidade no estoque
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

/// Exibe a imagem ampliada do calçado com suporte a proporção 16:10 e fallback seguro
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

    Widget construirImagem() {
      if (!calcado.temImagem) return fallback;

      if (calcado.imagemBytes != null) {
        return Image.memory(
          calcado.imagemBytes!,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => fallback,
        );
      }

      final url = calcado.imagemUrl!;
      if (url.startsWith('data:image')) {
        final idx = url.indexOf('base64,');
        if (idx != -1) {
          try {
            final bytes = base64Decode(url.substring(idx + 7));
            return Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => fallback,
            );
          } catch (_) {
            return fallback;
          }
        }
      }

      return Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

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
        child: construirImagem(),
      ),
    );
  }
}

/// Cartão retangular representando uma numeração na grade, com sua medida em cm e unidades disponíveis
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

/// Linha da tabela técnica de ficha do produto
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
