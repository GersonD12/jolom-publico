import 'package:flutter/material.dart';
import 'package:jolom/core/theme/theme.dart';

/// Variantes semánticas de badge (ámbar / celadón / marca).
enum StatusBadgeTone {
  /// Promociones, calificaciones, destacados.
  accent,

  /// Disponibilidad y citas confirmadas.
  success,

  /// Información / marca.
  brand,

  /// Neutro.
  neutral,
}

/// Escala visual del badge.
enum StatusBadgeSize {
  /// Compacto (estados en listas/cards).
  compact,

  /// Medio (acciones / chips de redes).
  medium,
}

/// Badge compacto para estados (disponible, promo, rating…).
class StatusBadgeWidget extends StatelessWidget {
  const StatusBadgeWidget({
    required this.label,
    this.tone = StatusBadgeTone.neutral,
    this.size = StatusBadgeSize.compact,
    this.icon,
    super.key,
  });

  final String label;
  final StatusBadgeTone tone;
  final StatusBadgeSize size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (Color bg, Color fg) = switch (tone) {
      StatusBadgeTone.accent => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      StatusBadgeTone.success => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
      StatusBadgeTone.brand => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
      StatusBadgeTone.neutral => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
    };

    final isMedium = size == StatusBadgeSize.medium;
    final iconSize = isMedium ? 16.0 : 14.0;
    final labelStyle = (isMedium ? textTheme.labelLarge : textTheme.labelMedium)
        ?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMedium ? AppSpacing.md : AppSpacing.sm,
        vertical: isMedium ? AppSpacing.xs : AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: fg),
            SizedBox(width: isMedium ? AppSpacing.xs : AppSpacing.xxs),
          ],
          Text(label, style: labelStyle),
        ],
      ),
    );
  }
}
