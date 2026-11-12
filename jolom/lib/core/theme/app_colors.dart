import 'package:flutter/material.dart';

/// Tokens de color de marca Jolom (modo claro y oscuro).
///
/// Los roles principales viven también en [ColorScheme] vía [AppTheme].
/// Usa esta clase para colores de marca o acentos fuera del esquema Material.
abstract final class AppColors {
  // --- Azul Bondi de marca ---
  static const Color brandLight = Color(0xFF0095B6);
  static const Color brandDark = Color(0xFF56D6EC);

  // --- Botón principal ---
  static const Color primaryLight = Color(0xFF006A7C);
  static const Color primaryDark = Color(0xFF56D6EC);

  // --- Texto sobre botón ---
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color onPrimaryDark = Color(0xFF00363F);

  // --- Fondo azul suave ---
  static const Color primaryContainerLight = Color(0xFFA9EDFA);
  static const Color primaryContainerDark = Color(0xFF00505F);

  // --- Ámbar de acento ---
  static const Color secondaryLight = Color(0xFF8B5000);
  static const Color secondaryDark = Color(0xFFFFB95F);

  // --- Fondo ámbar suave ---
  static const Color secondaryContainerLight = Color(0xFFFFDDB3);
  static const Color secondaryContainerDark = Color(0xFF673B00);

  // --- Celadón ---
  static const Color tertiaryLight = Color(0xFF3E6B50);
  static const Color tertiaryDark = Color(0xFFA4D3B4);

  // --- Fondo celadón ---
  static const Color tertiaryContainerLight = Color(0xFFBFECCF);
  static const Color tertiaryContainerDark = Color(0xFF285139);

  // --- Fondo general ---
  static const Color surfaceLight = Color(0xFFF7FAFB);
  static const Color surfaceDark = Color(0xFF0F1416);

  // --- Tarjetas ---
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF171C1E);

  // --- Superficie secundaria ---
  static const Color surfaceSecondaryLight = Color(0xFFE3F0F2);
  static const Color surfaceSecondaryDark = Color(0xFF253033);

  // --- Texto principal ---
  static const Color onSurfaceLight = Color(0xFF161D1F);
  static const Color onSurfaceDark = Color(0xFFE1E7E9);

  // --- Texto secundario ---
  static const Color onSurfaceVariantLight = Color(0xFF465256);
  static const Color onSurfaceVariantDark = Color(0xFFC0C8CB);

  // --- Bordes ---
  static const Color outlineLight = Color(0xFF6F797C);
  static const Color outlineDark = Color(0xFF899295);

  // --- Error / cancelación ---
  static const Color errorLight = Color(0xFFBA1A1A);
  static const Color errorDark = Color(0xFFFFB4AB);

  /// Azul Bondi según el brillo actual del tema.
  static Color brand(Brightness brightness) =>
      brightness == Brightness.dark ? brandDark : brandLight;

  /// Azul Bondi según el [BuildContext].
  static Color brandOf(BuildContext context) =>
      brand(Theme.of(context).brightness);
}
