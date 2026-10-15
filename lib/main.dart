import 'package:flutter/material.dart';
import 'screens/login_page.dart';
import 'services/sessao.dart';
import 'theme/app_theme.dart';

void main() {
  // Se a API recusar o token (sessão expirada), volta para o login de qualquer tela.
  Sessao.instance.aoExpirar = () {
    MyApp.navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage(sessaoExpirada: true)),
      (_) => false,
    );
  };
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Alternância de tema claro/escuro, acionada pelos botões das AppBars.
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

  /// Permite navegar sem ter um `context` (usado ao expirar a sessão).
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, modo, __) => MaterialApp(
        title: 'LandView Stock',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: modo,
        home: const LoginPage(),
      ),
    );
  }
}
