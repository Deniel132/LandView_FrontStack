import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parte2_flutter/config/loja.dart';
import 'package:parte2_flutter/widgets/contato_loja.dart';
import 'package:parte2_flutter/widgets/logo_loja.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'o logo da loja está declarado e pode ser carregado como asset',
    () async {
      final imagem = await rootBundle.load(Loja.logoAsset);

      expect(imagem.lengthInBytes, greaterThan(0));
      expect(Loja.logoAsset, 'assets/logo.png');
    },
  );

  testWidgets('o rodapé mostra Instagram, telefone e endereço', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: RodapeContato())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fale com a loja'), findsOneWidget);
    expect(find.text(Loja.instagram), findsOneWidget);
    expect(find.text(Loja.telefone), findsOneWidget);
    expect(find.text(Loja.endereco), findsOneWidget);
    expect(find.byType(LogoLoja), findsOneWidget);
  });
}
