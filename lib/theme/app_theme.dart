import 'package:flutter/material.dart';

/// Cores reutilizadas em telas, cartões, estados e ações do aplicativo.
class AppColors {
  static const ink = Color(0xFF0E1512);
  static const steel = Color(0xFF16201B);
  static const paper = Color(0xFFF0F2EE);
  static const grass = Color(0xFF17803F); // acento (botões, fundo)
  static const grassLight = Color(0xFF3DBA6E); // acento legível sobre fundo escuro
  static const hazard = Color(0xFFD99A2B);
  static const danger = Color(0xFFC0392B);
  static const mist = Color(0xFF8A988F);
  static const slate = Color(0xFF5C6A62);
}

class AppTheme {
  const AppTheme._();

  static const double radius = 14;
  static const double radiusLg = 18;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final accent = isDark ? AppColors.grassLight : AppColors.grass;
    final muted = isDark ? AppColors.mist : AppColors.slate;
    final linha = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : Colors.black.withValues(alpha: 0.09);

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.grass,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.grass,
      onPrimary: Colors.white,
      surface: isDark ? AppColors.steel : Colors.white,
      onSurface: isDark ? Colors.white : AppColors.ink,
      error: AppColors.danger,
    );

    final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme);

    OutlineInputBorder borda(Color cor, [double largura = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: cor, width: largura),
        );

    return base.copyWith(
      scaffoldBackgroundColor: isDark ? AppColors.ink : AppColors.paper,
      textTheme: base.textTheme.apply(
        bodyColor: isDark ? Colors.white : AppColors.ink,
        displayColor: isDark ? Colors.white : AppColors.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.ink : AppColors.paper,
        foregroundColor: isDark ? Colors.white : AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: isDark ? Colors.white : AppColors.ink,
        ),
      ),
      dividerTheme: DividerThemeData(space: 1, thickness: 1, color: linha),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF7F8F6),
        labelStyle: TextStyle(color: muted, fontSize: 14),
        floatingLabelStyle: TextStyle(color: accent),
        prefixIconColor: muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: borda(linha),
        enabledBorder: borda(linha),
        focusedBorder: borda(AppColors.grass, 1.6),
        errorBorder: borda(AppColors.danger),
        focusedErrorBorder: borda(AppColors.danger, 1.6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.grass,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.grass.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : AppColors.ink,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          side: BorderSide(color: linha),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.grass.withValues(alpha: 0.16),
          selectedForegroundColor: accent,
          side: BorderSide(color: linha),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.grass,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.steel : AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}

/// Atalhos de cor para que as telas respeitem o tema claro ou escuro atual.
extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get cardSurface => isDark ? AppColors.steel : Colors.white;
  Color get hairline =>
      isDark ? Colors.white.withValues(alpha: 0.09) : Colors.black.withValues(alpha: 0.09);
  Color get textMuted => isDark ? AppColors.mist : AppColors.slate;
  Color get textStrong => isDark ? Colors.white : AppColors.ink;
  Color get accent => isDark ? AppColors.grassLight : AppColors.grass;
}
