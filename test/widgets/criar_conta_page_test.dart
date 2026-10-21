import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parte2_flutter/screens/login_page.dart';

void main() {
  testWidgets('abre a tela de criar conta pelo login', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.tap(find.text('Criar uma conta'));
    await tester.pumpAndSettle();

    expect(find.text('Nova conta'), findsOneWidget);
    expect(find.text('Confirmar senha'), findsOneWidget);
    expect(
      find.textContaining('O modo demonstração não salva contas.'),
      findsOneWidget,
    );
  });

  testWidgets('valida campos obrigatórios antes do cadastro', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.tap(find.text('Criar uma conta'));
    await tester.pumpAndSettle();
    final botaoCriarConta = find.widgetWithText(ElevatedButton, 'Criar conta');
    await tester.ensureVisible(botaoCriarConta);
    await tester.pumpAndSettle();
    await tester.tap(botaoCriarConta);
    await tester.pumpAndSettle();

    expect(find.text('Informe o e-mail'), findsOneWidget);
    expect(find.text('Informe a senha'), findsOneWidget);
    expect(find.text('Confirme sua senha'), findsOneWidget);
  });
}
