import 'package:flutter_test/flutter_test.dart';
import 'package:parte2_flutter/models/calcado.dart';
import 'package:parte2_flutter/models/dashboard.dart';
import 'package:parte2_flutter/models/venda.dart';

void main() {
  group('Calcado', () {
    test('lê estoque e ordena tamanhos recebidos da API', () {
      final calcado = Calcado.fromJson({
        'id': 3,
        'nome': 'Air Zoom Pegasus 40',
        'marca': 'Nike',
        'tipo': 'tenis',
        'forma': 'padrao',
        'preco': 799.9,
        'estoque': 4,
        'tamanhos': [
          {'numeracao': 42, 'comprimento_cm': 28.2},
          {'numeracao': 41.5, 'comprimento_cm': 27.6},
        ],
      });

      expect(calcado.estoque, 4);
      expect(calcado.tamanhos.map((t) => t.numeracao), [41.5, 42]);
    });

    test('envia estoque sem incluir o id no corpo de criação', () {
      const calcado = Calcado(
        id: 3,
        nome: 'Air Zoom Pegasus 40',
        marca: 'Nike',
        tipo: TipoCalcado.tenis,
        forma: FormaCalcado.padrao,
        preco: 799.9,
        estoque: 4,
      );

      final json = calcado.toJson();

      expect(json['estoque'], 4);
      expect(json.containsKey('id'), isFalse);
    });
  });

  test('interpreta o resumo e as listas do dashboard', () {
    final dashboard = Dashboard.fromJson({
      'resumo': {
        'total_modelos': 8,
        'unidades_em_estoque': 186,
        'vendas_30_dias': 85,
        'modelos_acabando': 2,
        'modelos_com_excesso': 2,
        'limite_estoque_baixo': 5,
        'limite_estoque_alto': 40,
      },
      'mais_vendidos': [
        {
          'id': 3,
          'nome': 'Pegasus',
          'marca': 'Nike',
          'vendas': 19,
          'estoque': 4,
        },
      ],
      'estoque_baixo': [],
      'estoque_alto': [],
    });

    expect(dashboard.resumo.totalModelos, 8);
    expect(dashboard.resumo.limiteEstoqueBaixo, 5);
    expect(dashboard.maisVendidos.single.vendas, 19);
  });

  test('interpreta a resposta do registro de venda da API', () {
    final venda = VendaRegistrada.fromJson({
      'id': 42,
      'calcado_id': 3,
      'quantidade': 2,
      'estoque_atual': 2,
      'data_venda': '2026-10-06T20:00:00Z',
    });

    expect(venda.id, 42);
    expect(venda.calcadoId, 3);
    expect(venda.quantidade, 2);
    expect(venda.estoqueAtual, 2);
    expect(venda.dataVenda, DateTime.utc(2026, 10, 6, 20));
  });

  test('descontarDoTamanho baixa estoque do tamanho e do total do calçado', () {
    final calcado = Calcado(
      id: 1,
      nome: 'Air Zoom Pegasus 40',
      marca: 'Nike',
      tipo: TipoCalcado.tenis,
      forma: FormaCalcado.padrao,
      preco: 799.9,
      estoque: 9,
      tamanhos: Calcado.gerarTabelaPadrao(FormaCalcado.padrao),
    );

    final aposVenda = calcado.descontarDoTamanho(37, 1);

    expect(aposVenda.estoque, 8);
    expect(
      aposVenda.tamanhos.firstWhere((t) => t.numeracao == 37).estoque,
      0,
    );
  });
}
