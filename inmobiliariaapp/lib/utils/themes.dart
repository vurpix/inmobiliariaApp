// utils/themes.dart
import 'package:flutter/material.dart';

class AppThemes {
  // ==========================================
  // PALETA CLARA (Mapeada de tu YAML "Inmobiliaria App")
  // ==========================================
  static const Color primaryColorLight = Color(0xFF002045);   // Deep Blue (Legacy Weight)
  static const Color secondaryColorLight = Color(0xFF875200); // Warm Gold (Aspirational Accent)
  static const Color tertiaryColorLight = Color(0xFF172131);  // Slate
  static const Color backgroundColorLight = Color(0xFFF7FAFC); // Canvas off-white
  static const Color surfaceColorLight = Color(0xFFFFFFFF);     // Pure white cards
  static const Color textColorLight = Color(0xFF181C1E);       // On-Surface
  static const Color textSecondaryLight = Color(0xFF43474E);   // On-Surface Variant
  static const Color errorColorLight = Color(0xFFBA1A1A);
  static const Color successColorLight = Color(0xFF19a337);    // Green listing status

  // ==========================================
  // PALETA OSCURA (Mapeada de "Obsidian Estate")
  // ==========================================
  static const Color primaryColorDark = Color(0xFF3B82F6);     // Azul Eléctrico Vibrante
  static const Color secondaryColorDark = Color(0xFFFB923C);    // Naranja Neón
  static const Color tertiaryColorDark = Color(0xFF10b981);  // Slate
  static const Color backgroundColorDark = Color(0xFF0F172A);   // Neutral Oscuro Profundo
  static const Color surfaceColorDark = Color(0xFF1E293B);      // Gris Azulado
  static const Color textColorDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color errorColorDark = Color(0xFFF87171);
  static const Color successColorDark = Color(0xFF19a337);

  // --- TEMA CLARO NATIVO (MATERIAL 3) ---
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColorLight,
    scaffoldBackgroundColor: backgroundColorLight,
    fontFamily: 'Inter',
    
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColorLight,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),

    // Configuración estructural para botones según el diseño de tu marca
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF6AD55), // High-contrast Gold CTA
        foregroundColor: Colors.white,
        elevation: 0,
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Radius base 8px (0.5rem)
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),

    // Chips de características (e.g., "Parking", "Pool")
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFEDF2F7), // Low-contrast grey background
      labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: textSecondaryLight),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)), // Pill-shaped
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),

    // Ajustes simétricos para los campos de entrada de texto
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceColorLight,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), // Base 8px radius
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryColorLight, width: 2), // Focus Deep Blue
      ),
    ),

    // Tarjetas Inmuebles con sombras ambientales calculadas
    cardTheme: CardThemeData(
      color: surfaceColorLight,
      elevation: 0, // Desactivamos el estándar para inyectar tu sombra difusa personalizada
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // rounded-lg (16px)
    ),

    colorScheme: const ColorScheme.light(
      primary: primaryColorLight,
      secondary: secondaryColorLight,
      surface: surfaceColorLight,
      background: backgroundColorLight,
      error: errorColorLight,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textColorLight,
      onBackground: textColorLight,
    ),
  );

  // --- TEMA OSCURO NATIVO ---
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColorDark,
    scaffoldBackgroundColor: backgroundColorDark,
    fontFamily: 'Inter',
    
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceColorDark,
      foregroundColor: textColorDark,
      elevation: 0,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: secondaryColorDark,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: Colors.white10,
      labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: textColorDark),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceColorDark,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryColorDark, width: 2),
      ),
    ),

    cardTheme: CardThemeData(
      color: surfaceColorDark,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    colorScheme: const ColorScheme.dark(
      primary: primaryColorDark,
      secondary: secondaryColorDark,
      surface: surfaceColorDark,
      background: backgroundColorDark,
      error: errorColorDark,
      onPrimary: Colors.white,
      onSecondary: Colors.black87,
      onSurface: textColorDark,
      onBackground: textColorDark,
    ),
  );

  // --- MÉTODOS DE RETORNO DINÁMICO ---
  static Color getPrimaryColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? primaryColorDark : primaryColorLight;
  static Color getSecondaryColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? secondaryColorDark : secondaryColorLight;
  static Color getTertiaryColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? tertiaryColorDark : tertiaryColorLight;
  static Color getBackgroundColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? backgroundColorDark : backgroundColorLight;
  static Color getBackgroundColorDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? backgroundColorLight : backgroundColorDark;
  static Color getSurfaceColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? surfaceColorDark : surfaceColorLight;
  static Color getTextColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? textColorDark : textColorLight;
  static Color getTextColorWhite(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? textColorLight : textColorDark;
  static Color getTextSecondaryColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? textSecondaryDark : textSecondaryLight;
  static Color getErrorColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? errorColorDark : errorColorLight;
  static Color getSuccessColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? successColorDark : successColorLight;
}

extension ThemeColors on BuildContext {
  Color get primaryColor => AppThemes.getPrimaryColor(this);
  Color get secondaryColor => AppThemes.getSecondaryColor(this);
  Color get tertiaryColor => AppThemes.getTertiaryColor(this);
  Color get backgroundColor => AppThemes.getBackgroundColor(this);
  Color get backgroundColorDark => AppThemes.getBackgroundColorDark(this);
  Color get surfaceColor => AppThemes.getSurfaceColor(this);
  Color get textColor => AppThemes.getTextColor(this);
  Color get textColorWhite => AppThemes.getTextColorWhite(this);
  Color get textSecondaryColor => AppThemes.getTextSecondaryColor(this);
  Color get errorColor => AppThemes.getErrorColor(this);
  Color get successColor => AppThemes.getSuccessColor(this);
}

class ResponsiveUtils {
  static double getWidth(BuildContext context, double percentage) => MediaQuery.of(context).size.width * (percentage / 100);
  static double getHeight(BuildContext context, double percentage) => MediaQuery.of(context).size.height * (percentage / 100);
  static double getTextScaleFactor(BuildContext context) => MediaQuery.of(context).textScaleFactor;

  static double getFontSize(BuildContext context, double baseSize) {
    double scale = getTextScaleFactor(context);
    return baseSize * scale.clamp(0.8, 1.2);
  }
}