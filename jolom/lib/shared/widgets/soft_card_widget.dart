import 'package:flutter/material.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/shared/widgets/pressable_scale_widget.dart';

/// Tarjeta Soft UI con esquinas orgánicas y sombra difusa.
class SoftCardWidget extends StatelessWidget {
  const SoftCardWidget({
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.clipBehavior = Clip.antiAlias,
    this.elevated = true,
    this.translucent = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? color;
  final Clip clipBehavior;
  final bool elevated;
  final bool translucent;

  @override
  Widget build(BuildContext context) {
    final softUi = SoftUiTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final radius = borderRadius ?? softUi.cardRadius;
    final background =
        color ??
        (translucent ? softUi.translucentSurface : scheme.surfaceContainerLow);

    final card = AnimatedContainer(
      duration: AppMotion.durationOf(context, AppMotion.fast),
      curve: AppMotion.curveOf(context, AppMotion.decelerate),
      margin: margin,
      // Padding por defecto evita que el clip de las esquinas recorte el texto.
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        boxShadow: elevated ? softUi.cardShadow : null,
      ),
      clipBehavior: clipBehavior,
      child: child,
    );

    if (onTap == null) return card;

    return PressableScaleWidget(onTap: onTap, child: card);
  }
}
