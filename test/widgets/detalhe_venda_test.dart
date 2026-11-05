import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parte2_flutter/models/calcado.dart';
import 'package:parte2_flutter/models/venda.dart';
import 'package:parte2_flutter/screens/detalhe_page.dart';
import 'package:parte2_flutter/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ApiService.registrarVendaTeste = null;
    ApiService.atualizarTeste = null;
  });

  testWidgets('registra quantidade escolhida e atualiza estoque no detalhe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final calcado = Calcado(
      id: 1,
      nome: 'Air Zoom Pegasus 40',
      marca: 'Nike',
      tipo: TipoCalcado.tenis,
      forma: FormaCalcado.padrao,
      preco: 799.90,
      estoque: 18,
      tamanhos: Calcado.gerarTabelaPadrao(FormaCalcado.padrao),
    );
    final estoqueAntes = calcado.estoque;

    Calcado? calcadoSalvoNoBackend;
    ApiService.registrarVendaTeste = ({
      required int calcadoId,
      required int quantidade,
    }) async {
      return VendaRegistrada(
        id: 100,
        calcadoId: calcadoId,
        quantidade: quantidade,
        estoqueAtual: estoqueAntes - quantidade,
        dataVenda: DateTime.now(),
      );
    };
    ApiService.atualizarTeste = (c) async {
      calcadoSalvoNoBackend = c;
      return c;
    };

    await tester.pumpWidget(MaterialApp(home: DetalhePage(calcado: calcado)));
    await tester.ensureVisible(find.text('Registrar venda'));
    await tester.tap(find.text('Registrar venda'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('Registrar venda')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Aumentar quantidade'));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('Confirmar venda'));
    await tester.pumpAndSettle();

    expect(find.text('${estoqueAntes - 2} unidades'), findsOneWidget);
    expect(find.textContaining('Venda registrada: 2 unidades'), findsOneWidget);
    expect(calcadoSalvoNoBackend?.estoque, estoqueAntes - 2);
  });
}
