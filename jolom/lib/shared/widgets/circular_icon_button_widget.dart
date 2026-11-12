import 'package:flutter/material.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/shared/widgets/pressable_scale_widget.dart';

/// Botón circular para iconos (atrás, favorito, filtros, etc.).
class CircularIconButtonWidget extends StatelessWidget {
  const CircularIconButtonWidget({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = AppSpacing.minTapTarget,
    this.iconSize = 22,
    this.backgroundColor,
    this.foregroundColor,
    this.translucent = true,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool translucent;

  @override
  Widget build(BuildContext context) {
    final softUi = SoftUiTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final bg =
        backgroundColor ??
        (translucent
            ? softUi.translucentSurface
            : scheme.surfaceContainerHighest);
    final fg = foregroundColor ?? scheme.onSurface;

    final button = PressableScaleWidget(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: softUi.pressedShadow,
        ),
        child: Icon(icon, size: iconSize, color: fg),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
