import 'package:flutter/material.dart';
import 'package:jolom/core/theme/app_radius.dart';

/// Tokens visuales Soft UI / claymorphism (sombras, gradientes, radios).
@immutable
class SoftUiTheme extends ThemeExtension<SoftUiTheme> {
  const SoftUiTheme({
    required this.cardShadow,
    required this.floatingShadow,
    required this.pressedShadow,
    required this.ambientGradient,
    required this.cardRadius,
    required this.pillRadius,
    required this.translucentSurface,
    required this.navBarColor,
  });

  final List<BoxShadow> cardShadow;
  final List<BoxShadow> floatingShadow;
  final List<BoxShadow> pressedShadow;
  final LinearGradient ambientGradient;
  final BorderRadius cardRadius;
  final BorderRadius pillRadius;
  final Color translucentSurface;
  final Color navBarColor;

  /// Tema claro: sombras difusas claras, profundidad suave.
  factory SoftUiTheme.light(ColorScheme colorScheme) {
    return SoftUiTheme(
      cardShadow: const [
        BoxShadow(
          color: Color(0x140F1416),
          blurRadius: 24,
          offset: Offset(0, 10),
          spreadRadius: -4,
        ),
        BoxShadow(
          color: Color(0x0A0F1416),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
      floatingShadow: const [
        BoxShadow(
          color: Color(0x1F0F1416),
          blurRadius: 28,
          offset: Offset(0, 12),
          spreadRadius: -6,
        ),
        BoxShadow(
          color: Color(0x0F0F1416),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
      pressedShadow: const [
        BoxShadow(
          color: Color(0x0A0F1416),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
      ambientGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colorScheme.primaryContainer.withValues(alpha: 0.45),
          colorScheme.surface,
          colorScheme.surface,
        ],
        stops: const [0, 0.35, 1],
      ),
      cardRadius: AppRadius.card,
      pillRadius: AppRadius.pill,
      translucentSurface: colorScheme.surfaceContainerLow.withValues(
        alpha: 0.86,
      ),
      navBarColor: colorScheme.onSurface.withValues(alpha: 0.92),
    );
  }

  /// Tema oscuro: elevación por luz, no solo inversión de colores.
  factory SoftUiTheme.dark(ColorScheme colorScheme) {
    return SoftUiTheme(
      cardShadow: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 28,
          offset: Offset(0, 12),
          spreadRadius: -6,
        ),
        BoxShadow(
          color: Color(0x33FFFFFF),
          blurRadius: 0,
          offset: Offset(0, 0),
          spreadRadius: 0.5,
        ),
      ],
      floatingShadow: [
        const BoxShadow(
          color: Color(0x80000000),
          blurRadius: 32,
          offset: Offset(0, 14),
          spreadRadius: -8,
        ),
        BoxShadow(
          color: colorScheme.primary.withValues(alpha: 0.12),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
      pressedShadow: const [
        BoxShadow(
          color: Color(0x4D000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
      ambientGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colorScheme.primaryContainer.withValues(alpha: 0.55),
          colorScheme.surface,
          colorScheme.surface,
        ],
        stops: const [0, 0.4, 1],
      ),
      cardRadius: AppRadius.card,
      pillRadius: AppRadius.pill,
      translucentSurface: colorScheme.surfaceContainerLow.withValues(
        alpha: 0.82,
      ),
      navBarColor: colorScheme.surfaceContainerLow.withValues(alpha: 0.94),
    );
  }

  static SoftUiTheme of(BuildContext context) {
    final extension = Theme.of(context).extension<SoftUiTheme>();
    assert(extension != null, 'SoftUiTheme no está registrado en ThemeData');
    return extension!;
  }

  @override
  SoftUiTheme copyWith({
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? floatingShadow,
    List<BoxShadow>? pressedShadow,
    LinearGradient? ambientGradient,
    BorderRadius? cardRadius,
    BorderRadius? pillRadius,
    Color? translucentSurface,
    Color? navBarColor,
  }) {
    return SoftUiTheme(
      cardShadow: cardShadow ?? this.cardShadow,
      floatingShadow: floatingShadow ?? this.floatingShadow,
      pressedShadow: pressedShadow ?? this.pressedShadow,
      ambientGradient: ambientGradient ?? this.ambientGradient,
      cardRadius: cardRadius ?? this.cardRadius,
      pillRadius: pillRadius ?? this.pillRadius,
      translucentSurface: translucentSurface ?? this.translucentSurface,
      navBarColor: navBarColor ?? this.navBarColor,
    );
  }

  @override
  SoftUiTheme lerp(ThemeExtension<SoftUiTheme>? other, double t) {
    if (other is! SoftUiTheme) return this;
    return SoftUiTheme(
      cardShadow:
          BoxShadow.lerpList(cardShadow, other.cardShadow, t) ?? cardShadow,
      floatingShadow:
          BoxShadow.lerpList(floatingShadow, other.floatingShadow, t) ??
          floatingShadow,
      pressedShadow:
          BoxShadow.lerpList(pressedShadow, other.pressedShadow, t) ??
          pressedShadow,
      ambientGradient: LinearGradient.lerp(
        ambientGradient,
        other.ambientGradient,
        t,
      )!,
      cardRadius: BorderRadius.lerp(cardRadius, other.cardRadius, t)!,
      pillRadius: BorderRadius.lerp(pillRadius, other.pillRadius, t)!,
      translucentSurface: Color.lerp(
        translucentSurface,
        other.translucentSurface,
        t,
      )!,
      navBarColor: Color.lerp(navBarColor, other.navBarColor, t)!,
    );
  }
}
