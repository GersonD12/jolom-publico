import 'package:flutter/material.dart';
import 'package:jolom/core/theme/app_colors.dart';

/// Paletas de color integradas en la aplicación.
enum AppColorPalette {
  jolom(
    storageValue: 'jolom',
    label: 'Jolom',
    description: 'Azul Bondi, ámbar y celadón',
    seedColor: AppColors.brandLight,
  ),
  lavender(
    storageValue: 'lavender',
    label: 'Lavanda',
    description: 'Violeta suave y relajante',
    seedColor: Color(0xFF7157B5),
  ),
  coral(
    storageValue: 'coral',
    label: 'Coral',
    description: 'Coral cálido y durazno',
    seedColor: Color(0xFFB84F5D),
  ),
  forest(
    storageValue: 'forest',
    label: 'Bosque',
    description: 'Verde natural y sereno',
    seedColor: Color(0xFF3F6B4F),
  ),
  sunset(
    storageValue: 'sunset',
    label: 'Atardecer',
    description: 'Naranja y ámbar luminoso',
    seedColor: Color(0xFFA95A17),
  ),
  graphite(
    storageValue: 'graphite',
    label: 'Grafito',
    description: 'Blanco, negro y gris plata',
    seedColor: Color(0xFF4A4A4A),
  );

  const AppColorPalette({
    required this.storageValue,
    required this.label,
    required this.description,
    required this.seedColor,
  });

  final String storageValue;
  final String label;
  final String description;
  final Color seedColor;

  /// Convierte el valor local en una paleta; Jolom es el fallback estable.
  static AppColorPalette fromStorage(String? raw) {
    return AppColorPalette.values.firstWhere(
      (palette) => palette.storageValue == raw,
      orElse: () => AppColorPalette.jolom,
    );
  }

  /// Esquema Material 3 completo para modo claro u oscuro.
  ColorScheme colorScheme(Brightness brightness) {
    if (this == AppColorPalette.jolom) {
      return _jolomColorScheme(brightness);
    }
    if (this == AppColorPalette.graphite) {
      return _graphiteColorScheme(brightness);
    }
    return ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
  }
}

/// Tema monocromático; conserva rojo únicamente para estados de error.
ColorScheme _graphiteColorScheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  return ColorScheme(
    brightness: brightness,
    primary: isDark ? const Color(0xFFF2F2F2) : const Color(0xFF202124),
    onPrimary: isDark ? const Color(0xFF1A1A1A) : Colors.white,
    primaryContainer: isDark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFE5E5E5),
    onPrimaryContainer: isDark
        ? const Color(0xFFF5F5F5)
        : const Color(0xFF161616),
    secondary: isDark ? const Color(0xFFC7C7C7) : const Color(0xFF5F6368),
    onSecondary: isDark ? const Color(0xFF252525) : Colors.white,
    secondaryContainer: isDark
        ? const Color(0xFF464646)
        : const Color(0xFFE2E2E2),
    onSecondaryContainer: isDark
        ? const Color(0xFFF4F4F4)
        : const Color(0xFF202020),
    tertiary: isDark ? const Color(0xFFAFAFAF) : const Color(0xFF6E6E6E),
    onTertiary: isDark ? const Color(0xFF202020) : Colors.white,
    tertiaryContainer: isDark
        ? const Color(0xFF393939)
        : const Color(0xFFD8D8D8),
    onTertiaryContainer: isDark
        ? const Color(0xFFF0F0F0)
        : const Color(0xFF1C1C1C),
    error: isDark ? AppColors.errorDark : AppColors.errorLight,
    onError: isDark ? const Color(0xFF690005) : Colors.white,
    surface: isDark ? const Color(0xFF111111) : const Color(0xFFFAFAFA),
    onSurface: isDark ? const Color(0xFFEAEAEA) : const Color(0xFF181818),
    onSurfaceVariant: isDark
        ? const Color(0xFFC7C7C7)
        : const Color(0xFF4B4B4B),
    outline: isDark ? const Color(0xFF929292) : const Color(0xFF737373),
    outlineVariant: isDark ? const Color(0xFF383838) : const Color(0xFFD4D4D4),
    inverseSurface: isDark ? const Color(0xFFEAEAEA) : const Color(0xFF242424),
    onInverseSurface: isDark
        ? const Color(0xFF242424)
        : const Color(0xFFF5F5F5),
    inversePrimary: isDark ? const Color(0xFF333333) : const Color(0xFFE4E4E4),
    surfaceContainerLowest: isDark ? Colors.black : Colors.white,
    surfaceContainerLow: isDark
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFFFFFFF),
    surfaceContainer: isDark
        ? const Color(0xFF202020)
        : const Color(0xFFF4F4F4),
    surfaceContainerHigh: isDark
        ? const Color(0xFF292929)
        : const Color(0xFFEDEDED),
    surfaceContainerHighest: isDark
        ? const Color(0xFF343434)
        : const Color(0xFFE5E5E5),
  );
}

/// Mantiene exactamente los colores actuales cuando la paleta es Jolom.
ColorScheme _jolomColorScheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  return ColorScheme(
    brightness: brightness,
    primary: isDark ? AppColors.primaryDark : AppColors.primaryLight,
    onPrimary: isDark ? AppColors.onPrimaryDark : AppColors.onPrimaryLight,
    primaryContainer: isDark
        ? AppColors.primaryContainerDark
        : AppColors.primaryContainerLight,
    onPrimaryContainer: isDark
        ? AppColors.primaryContainerLight
        : AppColors.onPrimaryDark,
    secondary: isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
    onSecondary: isDark
        ? AppColors.secondaryContainerDark
        : AppColors.onPrimaryLight,
    secondaryContainer: isDark
        ? AppColors.secondaryContainerDark
        : AppColors.secondaryContainerLight,
    onSecondaryContainer: isDark
        ? AppColors.secondaryContainerLight
        : AppColors.secondaryLight,
    tertiary: isDark ? AppColors.tertiaryDark : AppColors.tertiaryLight,
    onTertiary: isDark
        ? AppColors.tertiaryContainerDark
        : AppColors.onPrimaryLight,
    tertiaryContainer: isDark
        ? AppColors.tertiaryContainerDark
        : AppColors.tertiaryContainerLight,
    onTertiaryContainer: isDark
        ? AppColors.tertiaryContainerLight
        : AppColors.tertiaryLight,
    error: isDark ? AppColors.errorDark : AppColors.errorLight,
    onError: isDark ? const Color(0xFF690005) : AppColors.onPrimaryLight,
    surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
    onSurface: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
    onSurfaceVariant: isDark
        ? AppColors.onSurfaceVariantDark
        : AppColors.onSurfaceVariantLight,
    outline: isDark ? AppColors.outlineDark : AppColors.outlineLight,
    outlineVariant: isDark
        ? AppColors.surfaceSecondaryDark
        : AppColors.surfaceSecondaryLight,
    inverseSurface: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
    onInverseSurface: isDark ? AppColors.surfaceDark : AppColors.cardLight,
    inversePrimary: isDark ? AppColors.primaryLight : AppColors.primaryDark,
    surfaceContainerHighest: isDark
        ? AppColors.surfaceSecondaryDark
        : AppColors.surfaceSecondaryLight,
    surfaceContainerHigh: isDark
        ? AppColors.cardDark
        : AppColors.surfaceSecondaryLight,
    surfaceContainer: isDark ? AppColors.cardDark : AppColors.cardLight,
    surfaceContainerLow: isDark ? AppColors.cardDark : AppColors.cardLight,
    surfaceContainerLowest: isDark
        ? AppColors.surfaceDark
        : AppColors.cardLight,
  );
}
