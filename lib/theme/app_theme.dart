import 'package:flutter/material.dart';

class AppColors {
  // ── Modo oscuro — colores del main.dart original ──────────────────
  static const bg          = Color(0xFF051027);   // fondo de todas las pantallas (antes 0xFF1A1A2E)
  static const surface     = Color(0xFF12121F);   // surface original
  static const surfaceHigh = Color(0xFF1F1F38);
  static const border      = Color(0xFF2A2A4A);
  static const accent      = Color(0xFF00E5CC);   // teal como principal (igual que main.dart)
  static const teal        = Color(0xFF00E5CC);
  static const turquesa    = Color(0xFF1CE7B2);   // barra superior: misma línea de diseño en toda la app
  static const warn        = Color(0xFFFF5C5C);
  static const gold        = Color(0xFFFFB347);
  static const blue        = Color(0xFF0066FF);   // azul del gradiente del botón TTS
  static const purple      = Color(0xFFBB86FC);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textMid     = Color(0xB3FFFFFF); // white70
  static const textDim     = Color(0xFF9090B0);

  // ── Modo claro — mismos acentos, fondos invertidos ────────────────
  static const bgLight          = Color(0xFFF0F4FF);
  static const surfaceLight     = Color(0xFFFFFFFF);
  static const surfaceHighLight = Color(0xFFE8EEF8);
  static const borderLight      = Color(0xFFCCDDEE);
  static const accentLight      = Color(0xFF00B8A3);  // teal más oscuro para fondo claro
  static const tealLight        = Color(0xFF00B8A3);
  static const warnLight        = Color(0xFFD32F2F);
  static const goldLight        = Color(0xFFE07B00);
  static const blueLight        = Color(0xFF0044CC);
  static const purpleLight      = Color(0xFF7B3FD4);
  static const textPrimaryLight = Color(0xFF1A1A2E);  // invertido del bg oscuro
  static const textMidLight     = Color(0xFF3A3A5C);
  static const textDimLight     = Color(0xFF7070A0);

  // ── Cards de menú (VozMenuCard) ────────────────────────────────────
  // Fijos en ambos temas (igual criterio que `turquesa` arriba): estas
  // cards mantienen siempre el lenguaje visual "azul profundo" de la
  // AppBar, tanto en modo claro como oscuro.
  static const cardBgStart        = Color(0xFF0B1C36);
  static const cardBgEnd          = Color(0xFF101D35);
  static const cardBorder         = Color(0xFF203653);
  static const cardIconBg         = Color(0xFF153052);
  static const cardIconContent    = Color(0xFFDCEBFF);
  static const cardTitle          = Color(0xFFF5F7FB);
  static const cardSubtitle       = Color(0xFFAEB8C9);
  static const cardChevron        = Color(0xFFAFC3E6);
  static const cardAccentTurquesa = Color(0xFF16DFC1); // acento card "Privacidad"

  // ── Barra de navegación inferior (VozBottomNavigationBar) ──────────
  // Fijos en ambos temas (igual criterio que `turquesa`/cards arriba):
  // turquesa suave que contrasta con el azul noche del resto de la
  // app, en vez del tono oscuro anterior.
  static const navBarBg         = Color(0xFF6ACBC3); // fondo de toda la barra
  // Negro puro: el azul noche inicial (#071525) se leía con poco
  // contraste en dispositivo real (iconos de contorno fino sobre
  // turquesa), así que se cambia a negro para maximizar la
  // legibilidad, a petición expresa.
  static const navBarContent    = Color(0xFF000000); // iconos y labels, seleccionado o no
  static const navBarSelectedBg = Color(0xFFA8E5DF); // "pill" del elemento activo

  // ── Card de estado de conexión (VozConnectionStatusCard) ───────────
  // Fijos en ambos temas: superficie translúcida pensada para
  // destacar sobre el fondo azul noche de la app, sin degradados,
  // neón ni glassmorphism.
  static const statusCardBg         = Color(0x1AFFFFFF); // blanco, ~10% opacidad
  static const statusCardBorder     = Color(0x24FFFFFF); // blanco, ~14% opacidad
  static const statusCardIcon       = Color(0xFFD1D9E6);
  static const statusCardAction     = Color(0xFF8FB4E5); // texto "Reintentar"
  static const statusCardOfflineDot = Color(0xFFFF6B6B); // indicador sin conexión
  static const statusCardLoading    = cardAccentTurquesa; // spinner "Conectando…"

  // ── Cards de colaboradores (fondo claro fijo) ──────────────────────
  // Excepción deliberada al resto de cards (siempre navy): los
  // logotipos de las entidades están pensados para fondo blanco, así
  // que esta card es blanca en los dos temas, con texto oscuro.
  static const collabCardBorder = Color(0xFFE3E7EF);

  // ── Helper: color de categoría ────────────────────────────────────
  static Color catColor(String cat, {bool light = false}) {
    switch (cat) {
      case 'Urgente':     return light ? warnLight   : warn;
      case 'Saludos':     return light ? tealLight   : teal;
      case 'Necesidades': return light ? goldLight   : gold;
      case 'Respuestas':  return light ? blueLight   : blue;
      default:            return light ? purpleLight : purple;
    }
  }

  static Color adaptive(BuildContext context, Color dark, Color light) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}

class AppTheme {
  // ── MODO OSCURO ───────────────────────────────────────────────────
  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Montserrat'),
    colorScheme: const ColorScheme.dark(
      primary:   AppColors.teal,
      secondary: AppColors.blue,
      surface:   AppColors.surface,
      error:     AppColors.warn,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.turquesa,
      foregroundColor: Colors.black,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        fontFamily: 'Montserrat',
      ),
      iconTheme: IconThemeData(color: Colors.black),
      actionsIconTheme: IconThemeData(color: Colors.black),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.navBarBg,
      selectedItemColor:   AppColors.teal,
      unselectedItemColor: Color(0x61FFFFFF), // white38
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle:   TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
    cardColor: AppColors.surface,
    dividerColor: const Color(0x1AFFFFFF), // white10
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surface,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.teal, width: 1.8),
        foregroundColor: AppColors.teal,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.teal : AppColors.textDim,
      ),
      trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
            ? const Color(0x6600E5CC)
            : AppColors.border,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor:   AppColors.teal,
      inactiveTrackColor: Color(0x1FFFFFFF), // white12
      thumbColor:         AppColors.teal,
      overlayColor:       Color(0x2600E5CC),
      trackHeight: 3,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.teal,
      foregroundColor: AppColors.bg,
    ),
    textTheme: base.textTheme.apply(fontFamily: 'Montserrat').merge(const TextTheme(
      bodyLarge:  TextStyle(color: AppColors.textPrimary),
      bodyMedium: TextStyle(color: AppColors.textPrimary),
      bodySmall:  TextStyle(color: Color(0xB3FFFFFF)), // white70
      labelSmall: TextStyle(color: AppColors.textDim),
    )),
    );
  }

  // ── MODO CLARO ────────────────────────────────────────────────────
  static ThemeData get light {
    final base = ThemeData.light();
    return base.copyWith(
    scaffoldBackgroundColor: AppColors.bgLight,
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Montserrat'),
    colorScheme: const ColorScheme.light(
      primary:   AppColors.tealLight,
      secondary: AppColors.blueLight,
      surface:   AppColors.surfaceLight,
      error:     AppColors.warnLight,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.turquesa,
      foregroundColor: Colors.black,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        fontFamily: 'Montserrat',
      ),
      iconTheme: IconThemeData(color: Colors.black),
      actionsIconTheme: IconThemeData(color: Colors.black),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceLight,
      selectedItemColor:   AppColors.tealLight,
      unselectedItemColor: AppColors.textDimLight,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle:   TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
    cardColor: AppColors.surfaceLight,
    dividerColor: AppColors.borderLight,
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceLight,
      contentTextStyle: TextStyle(color: AppColors.textPrimaryLight),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.tealLight, width: 1.8),
        foregroundColor: AppColors.tealLight,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.tealLight : AppColors.textDimLight,
      ),
      trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
            ? const Color(0x6600B8A3)
            : AppColors.borderLight,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor:   AppColors.tealLight,
      inactiveTrackColor: AppColors.borderLight,
      thumbColor:         AppColors.tealLight,
      overlayColor:       Color(0x2600B8A3),
      trackHeight: 3,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.tealLight,
      foregroundColor: AppColors.bgLight,
    ),
    textTheme: base.textTheme.apply(fontFamily: 'Montserrat').merge(const TextTheme(
      bodyLarge:  TextStyle(color: AppColors.textPrimaryLight),
      bodyMedium: TextStyle(color: AppColors.textPrimaryLight),
      bodySmall:  TextStyle(color: AppColors.textMidLight),
      labelSmall: TextStyle(color: AppColors.textDimLight),
    )),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME PROVIDER
// ─────────────────────────────────────────────────────────────────────────────


// ── Adaptive colors — use as: AppColors.of(context).bg etc. ──────
class AdaptiveColors {
  final bool _d;
  const AdaptiveColors(this._d);
  Color get bg          => _d ? AppColors.bg          : AppColors.bgLight;
  Color get surface     => _d ? AppColors.surface      : AppColors.surfaceLight;
  Color get surfaceHigh => _d ? AppColors.surfaceHigh  : AppColors.surfaceHighLight;
  Color get border      => _d ? AppColors.border       : AppColors.borderLight;
  Color get accent      => _d ? AppColors.accent       : AppColors.accentLight;
  Color get teal        => _d ? AppColors.teal         : AppColors.tealLight;
  Color get turquesa    => AppColors.turquesa; // misma barra superior en ambos modos
  Color get navBarBg         => AppColors.navBarBg; // misma barra inferior en ambos modos
  Color get navBarContent    => AppColors.navBarContent;
  Color get navBarSelectedBg => AppColors.navBarSelectedBg;

  Color get statusCardBg         => AppColors.statusCardBg;
  Color get statusCardBorder     => AppColors.statusCardBorder;
  Color get statusCardIcon       => AppColors.statusCardIcon;
  Color get statusCardAction     => AppColors.statusCardAction;
  Color get statusCardOfflineDot => AppColors.statusCardOfflineDot;
  Color get statusCardLoading    => AppColors.statusCardLoading;

  Color get collabCardBorder => AppColors.collabCardBorder;
  Color get cardBgStart        => AppColors.cardBgStart;
  Color get cardBgEnd          => AppColors.cardBgEnd;
  Color get cardBorder         => AppColors.cardBorder;
  Color get cardIconBg         => AppColors.cardIconBg;
  Color get cardIconContent    => AppColors.cardIconContent;
  Color get cardTitle          => AppColors.cardTitle;
  Color get cardSubtitle       => AppColors.cardSubtitle;
  Color get cardChevron        => AppColors.cardChevron;
  Color get cardAccentTurquesa => AppColors.cardAccentTurquesa;
  Color get warn        => _d ? AppColors.warn         : AppColors.warnLight;
  Color get gold        => _d ? AppColors.gold         : AppColors.goldLight;
  Color get blue        => _d ? AppColors.blue         : AppColors.blueLight;
  Color get purple      => _d ? AppColors.purple       : AppColors.purpleLight;
  Color get textPrimary => _d ? AppColors.textPrimary  : AppColors.textPrimaryLight;
  Color get textMid     => _d ? AppColors.textMid      : AppColors.textMidLight;
  Color get textDim     => _d ? AppColors.textDim      : AppColors.textDimLight;
  static AdaptiveColors of(BuildContext context) =>
      AdaptiveColors(Theme.of(context).brightness == Brightness.dark);
}