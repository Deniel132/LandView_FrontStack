import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parte2_flutter/screens/detalhe_page.dart';
import 'package:parte2_flutter/services/dados_demo.dart';

void main() {
  testWidgets('registra quantidade escolhida e atualiza estoque no detalhe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final calcado = (await tester.runAsync(DadosDemo.instance.listar))!.first;
    final estoqueAntes = calcado.estoque;
    final id = calcado.id!;

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
    final calcadoAtualizado = await tester.runAsync(
      () => DadosDemo.instance.buscar(id),
    );
    expect(calcadoAtualizado!.estoque, estoqueAntes - 2);
  });
}
