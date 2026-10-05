import 'package:flutter/material.dart';
import 'screens/home_page.dart';
import 'theme/app_theme.dart';

/// Ponto de entrada do aplicativo Flutter.
void main() => runApp(const MyApp());

/// Configura temas e abre o catálogo como primeira tela do aplicativo.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Alternância de tema claro/escuro, acionada pelo botão da AppBar.
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, modo, __) => MaterialApp(
        title: 'Provador Virtual',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: modo,
        home: const HomePage(),
      ),
    );
  }
}
