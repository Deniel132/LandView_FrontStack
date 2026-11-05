// Importa os componentes e estilos visuais do Flutter
import 'package:flutter/material.dart';

/// Paleta cromática oficial da Land View: azul institucional, tons de grafite, papel quente e cores semânticas.
class AppColors {
  // Tom grafite profundo quase preto para fundos no modo escuro e textos no modo claro
  static const ink = Color(0xFF0E1512);

  // Tom aço escuro utilizado como superfície de cartões no modo escuro
  static const steel = Color(0xFF16201B);

  // Tom papel quente suave utilizado como fundo principal de tela no modo claro
  static const paper = Color(0xFFF0F2EE);

  // Azul institucional oficial da marca Land View
  static const brand = Color(0xFF0754B8);

  // Tom de azul mais claro para contraste e legibilidade sobre fundos escuros
  static const brandLight = Color(0xFF6FA8E8);

  // Verde semântico para indicar sucesso, aprovação e estoque saudável
  static const success = Color(0xFF1E8449);

  // Verde claro com alto contraste para modo escuro
  static const successLight = Color(0xFF52BE80);

  // Amarelo âmbar para indicar alertas e atenção (estoque baixo ou acabando)
  static const hazard = Color(0xFFD99A2B);

  // Vermelho para indicar erros, exclusões ou estoque zerado
  static const danger = Color(0xFFC0392B);

  // Cinza claro para textos secundários no modo escuro
  static const mist = Color(0xFF8A988F);

  // Cinza escuro para textos secundários e legendas no modo claro
  static const slate = Color(0xFF5C6A62);

  // Azul informativo para indicar produtos com estoque alto ou excessivo
  static const info = Color(0xFF2F6FB8);

  // Azul claro informativo para o modo escuro
  static const infoLight = Color(0xFF6FA8E8);
}

/// Define os temas completos (Light e Dark) e estilos de botões, inputs, diálogos e cards do app.
class AppTheme {
  // Construtor privado para impedir instanciação da classe de tema
  const AppTheme._();

  // Raio de curvatura padrão dos cantos (14 pixels)
  static const double radius = 14;

  // Raio de curvatura ampliado para caixas de diálogo e modais (18 pixels)
  static const double radiusLg = 18;

  // Fábrica para gerar a configuração de tema claro
  static ThemeData light() => _build(Brightness.light);

  // Fábrica para gerar a configuração de tema escuro
  static ThemeData dark() => _build(Brightness.dark);

  // Constrói o ThemeData dinamicamente baseado no brilho (Light ou Dark)
  static ThemeData _build(Brightness brightness) {
    // Flag booleana que indica se é o modo escuro
    final isDark = brightness == Brightness.dark;
    // Cor de destaque (brand no claro, brandLight no escuro)
    final accent = isDark ? AppColors.brandLight : AppColors.brand;
    // Cor secundária de textos e legendas
    final muted = isDark ? AppColors.mist : AppColors.slate;
    // Cor semitransparente para bordas e linhas divisórias
    final linha = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : Colors.black.withValues(alpha: 0.09);

    // Esquema de cores Material 3 gerado a partir do azul da marca
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.brand,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.brand,
          onPrimary: Colors.white,
          surface: isDark ? AppColors.steel : Colors.white,
          onSurface: isDark ? Colors.white : AppColors.ink,
          error: AppColors.danger,
        );

    // Instancia o tema base com suporte a Material 3
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );

    // Função utilitária local para criar bordas arredondadas consistentes nos inputs
    OutlineInputBorder borda(Color cor, [double largura = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: cor, width: largura),
        );

    // Retorna a cópia do tema base customizada com todos os componentes da Land View
    return base.copyWith(
      // Cor de fundo padrão de todas as telas (Scaffold)
      scaffoldBackgroundColor: isDark ? AppColors.ink : AppColors.paper,
      // Configuração global de tipografia e cores de fonte
      textTheme: base.textTheme.apply(
        bodyColor: isDark ? Colors.white : AppColors.ink,
        displayColor: isDark ? Colors.white : AppColors.ink,
      ),
      // Estilização padronizada da barra superior (AppBar)
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
      // Estilização das linhas de separação (Divider)
      dividerTheme: DividerThemeData(space: 1, thickness: 1, color: linha),
      // Estilização dos campos de digitação (TextField / TextFormField)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF7F8F6),
        labelStyle: TextStyle(color: muted, fontSize: 14),
        hintStyle: TextStyle(color: muted.withValues(alpha: 0.7), fontSize: 14),
        floatingLabelStyle: TextStyle(color: accent, fontWeight: FontWeight.w600),
        prefixIconColor: muted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: borda(linha),
        enabledBorder: borda(linha),
        focusedBorder: borda(AppColors.brand, 1.6),
        errorBorder: borda(AppColors.danger),
        focusedErrorBorder: borda(AppColors.danger, 1.6),
      ),
      // Estilização dos botões principais com fundo preenchido (ElevatedButton)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      // Estilização dos botões secundários com borda (OutlinedButton)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : AppColors.ink,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          side: BorderSide(color: linha),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      // Estilização dos seletores em formato de pílula segmentada (SegmentedButton)
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.brand.withValues(alpha: 0.16),
          selectedForegroundColor: accent,
          side: BorderSide(color: linha),
        ),
      ),
      // Estilização do botão flutuante de ação (FloatingActionButton)
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      // Estilização visual das janelas de diálogo (AlertDialog)
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.steel : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      // Estilização das notificações temporárias do rodapé (SnackBar)
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.steel : AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Extensão de conveniência em BuildContext que expõe atalhos rápidos de cores semânticas,
/// eliminando a necessidade de repetir checagens manuais `isDark ? corA : corB` nos componentes.
extension AppThemeX on BuildContext {
  // Retorna se o contexto atual está renderizando no modo escuro
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // Cor de superfície para cartões principais
  Color get cardSurface => isDark ? AppColors.steel : Colors.white;

  // Cor de superfície sutil para fundos internos de seções e caixas
  Color get subtleSurface => isDark
      ? Colors.white.withValues(alpha: 0.04)
      : const Color(0xFFF5F6F3);

  // Cor ultrafina para bordas e linhas divisórias
  Color get hairline => isDark
      ? Colors.white.withValues(alpha: 0.09)
      : Colors.black.withValues(alpha: 0.09);

  // Cor para textos secundários e legendas de apoio
  Color get textMuted => isDark ? AppColors.mist : AppColors.slate;

  // Cor de alto contraste para textos principais e títulos
  Color get textStrong => isDark ? Colors.white : AppColors.ink;

  // Cor de destaque principal (azul) adaptada ao modo de luz
  Color get accent => isDark ? AppColors.brandLight : AppColors.brand;

  // Cor informativa (azul) para estoque em excesso
  Color get info => isDark ? AppColors.infoLight : AppColors.info;

  // Cor de sucesso (verde) adaptada ao brilho da tela
  Color get success => isDark ? AppColors.successLight : AppColors.success;
}
