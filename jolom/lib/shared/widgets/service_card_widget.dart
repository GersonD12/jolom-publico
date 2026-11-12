import 'package:flutter/material.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/shared/widgets/pressable_scale_widget.dart';

/// Tarjeta táctil de servicio (nombre, duración, precio).
class ServiceCardWidget extends StatelessWidget {
  const ServiceCardWidget({
    required this.title,
    required this.priceLabel,
    this.durationLabel,
    this.subtitle,
    this.selected = false,
    this.enabled = true,
    this.onTap,
    super.key,
  });

  final String title;
  final String priceLabel;
  final String? durationLabel;
  final String? subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final softUi = SoftUiTheme.of(context);
    final duration = AppMotion.durationOf(context, AppMotion.fast);

    return PressableScaleWidget(
      enabled: enabled,
      onTap: onTap,
      child: AnimatedContainer(
        duration: duration,
        curve: AppMotion.curveOf(context, AppMotion.decelerate),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          borderRadius: softUi.cardRadius,
          boxShadow: softUi.cardShadow,
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(subtitle!, style: textTheme.bodySmall),
                  ],
                  if (durationLabel != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(durationLabel!, style: textTheme.labelMedium),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    priceLabel,
                    style: textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Solo visual: el tap lo captura PressableScaleWidget de la card.
            IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: enabled
                      ? scheme.primary
                      : scheme.primary.withValues(alpha: 0.35),
                  borderRadius: AppRadius.pill,
                ),
                child: Text(
                  'Reservar',
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selector de franja horaria con estado claro.
class TimeSlotChipWidget extends StatelessWidget {
  const TimeSlotChipWidget({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    super.key,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final duration = AppMotion.durationOf(context, AppMotion.fast);

    return PressableScaleWidget(
      enabled: enabled,
      onTap: enabled ? () => onSelected(!selected) : null,
      child: AnimatedContainer(
        duration: duration,
        curve: AppMotion.curveOf(context, AppMotion.decelerate),
        constraints: const BoxConstraints(
          minWidth: AppSpacing.minTapTarget,
          minHeight: AppSpacing.minTapTarget,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: !enabled
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.45)
              : selected
              ? scheme.primary
              : scheme.surfaceContainerHighest,
          borderRadius: AppRadius.pill,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: textTheme.labelLarge?.copyWith(
            color: !enabled
                ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
                : selected
                ? scheme.onPrimary
                : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
