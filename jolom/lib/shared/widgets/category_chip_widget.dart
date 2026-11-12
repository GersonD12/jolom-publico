import 'package:flutter/material.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/shared/widgets/pressable_scale_widget.dart';

/// Chip de categoría redondeado con contraste claro al seleccionarse.
class CategoryChipWidget extends StatelessWidget {
  const CategoryChipWidget({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final duration = AppMotion.durationOf(context, AppMotion.fast);

    return PressableScaleWidget(
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: duration,
        curve: AppMotion.curveOf(context, AppMotion.decelerate),
        constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: AppRadius.chip,
        ),
        alignment: Alignment.center,
        child: AnimatedDefaultTextStyle(
          duration: duration,
          style: (textTheme.labelLarge ?? const TextStyle()).copyWith(
            color: selected ? scheme.onPrimary : scheme.onSurface,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
