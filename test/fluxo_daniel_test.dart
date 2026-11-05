// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:parte2_flutter/models/calcado.dart';
import 'package:parte2_flutter/services/api_service.dart';
import 'package:parte2_flutter/services/sessao.dart';

void main() {
  
  group('Validação do Fluxo Completo Solicitado por Daniel', () {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final emailTeste = 'daniel.teste.$timestamp@landview.com';
    const senhaTeste = 'SenhaForte123!';
    int? produtoIdCriado;

    test('1. Teste de Cadastro de Usuário (Conta de Vendedor)', () async {
      print('\n--- [TESTE 1/6] Criando usuário: $emailTeste ---');
      await ApiService.instance.criarConta(
        emailTeste,
        senhaTeste,
        role: 'SELLER',
      );
      print('✓ Usuário cadastrado com sucesso!');
    });

    test('2. Teste de Login com o Usuário Criado', () async {
      print('\n--- [TESTE 2/6] Autenticando com usuário recém-criado ---');
      final usuario = await ApiService.instance.login(emailTeste, senhaTeste);

      expect(usuario.email, equals(emailTeste));
      expect(Sessao.instance.logado, isTrue);
      expect(Sessao.instance.token, isNotNull);
      print('✓ Login realizado com sucesso!');
      print('  Token: ${Sessao.instance.token?.substring(0, 15)}...');
      print('  Perfil: ${usuario.perfil}');
    });

    test('3. Teste de Cadastro de Calçado (Produto + Categoria + Estoque Inicial)', () async {
      print('\n--- [TESTE 3/6] Cadastrando novo modelo de calçado ---');
      final novoCalcado = Calcado(
        nome: 'Tênis Daniel Pro Teste ${timestamp % 1000}',
        marca: 'LandView Sports',
        tipo: TipoCalcado.tenis,
        forma: FormaCalcado.padrao,
        preco: 299.90,
        estoque: 10, // Estoque inicial de 10 unidades
      );

      final criado = await ApiService.instance.criar(novoCalcado);

      expect(criado.id, isNotNull);
      expect(criado.nome, equals(novoCalcado.nome));
      expect(criado.estoque, equals(10));
      expect(criado.preco, equals(299.90));

      produtoIdCriado = criado.id;
      print('✓ Calçado cadastrado com sucesso!');
      print('  ID do Produto: $produtoIdCriado');
      print('  Nome: ${criado.nome}');
      print('  Estoque Inicial: ${criado.estoque} unidades');
      print('  Preço: R\$ ${criado.preco.toStringAsFixed(2)}');
    });

    test('4. Teste de Consulta e Busca do Calçado Cadastrado', () async {
      expect(produtoIdCriado, isNotNull);
      print('\n--- [TESTE 4/6] Consultando calçado ID $produtoIdCriado no catálogo ---');

      final buscado = await ApiService.instance.buscar(produtoIdCriado!);

      expect(buscado.id, equals(produtoIdCriado));
      expect(buscado.estoque, equals(10));
      print('✓ Calçado localizado e validado no catálogo com 10 unidades.');
    });

    test('5. Teste de Saída de Estoque (Registrar Venda de 3 Unidades)', () async {
      expect(produtoIdCriado, isNotNull);
      print('\n--- [TESTE 5/6] Realizando SAÍDA de 3 unidades do produto ID $produtoIdCriado ---');

      final venda = await ApiService.instance.registrarVenda(
        calcadoId: produtoIdCriado!,
        quantidade: 3,
      );

      expect(venda.quantidade, equals(3));
      expect(venda.estoqueAtual, equals(7)); // 10 - 3 = 7

      // Confere se a busca no catálogo reflete a baixa imediata
      final conferido = await ApiService.instance.buscar(produtoIdCriado!);
      expect(conferido.estoque, equals(7));

      print('✓ Saída de estoque realizada com sucesso!');
      print('  Quantidade baixada: 3 unidades');
      print('  Novo saldo de estoque: ${conferido.estoque} unidades (Confirmado: 10 - 3 = 7)');
    });

    test('6. Teste de Auditoria no Histórico de Saídas (GET /stock-exit/)', () async {
      expect(produtoIdCriado, isNotNull);
      print('\n--- [TESTE 6/6] Verificando histórico de saídas registradas ---');

      final saidas = await ApiService.instance.listarSaidas(
        idProduct: produtoIdCriado,
      );

      expect(saidas.isNotEmpty, isTrue);
      final ultimaSaida = saidas.first;
      expect(ultimaSaida.idProduto, equals(produtoIdCriado));
      expect(ultimaSaida.quantidade, equals(3));

      print('✓ Histórico de auditoria conferido!');
      print('  Registro de saída ID: #${ultimaSaida.id}');
      print('  Produto: ${ultimaSaida.nomeProduto ?? produtoIdCriado}');
      print('  Quantidade registrada: -${ultimaSaida.quantidade} un.');
      print('  Estoque ID: #${ultimaSaida.idEstoque}');
      print('\n======================================================');
      print('FLUXO COMPLETO VALIDADO COM 100% DE SUCESSO!');
      print('======================================================');
    });

    // Limpa os dados de teste criados no banco para manter o catálogo 100% limpo
    tearDownAll(() async {
      if (produtoIdCriado != null) {
        try {
          await ApiService.instance.excluir(produtoIdCriado!);
          print('✓ Calçado temporário de teste ID $produtoIdCriado removido com sucesso!');
        } catch (_) {}
      }
    });
  });
}
