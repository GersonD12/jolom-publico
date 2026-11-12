import 'package:flutter/material.dart';
import 'package:jolom/core/theme/theme.dart';

/// Botón principal en forma de píldora (p. ej. “Reservar cita”).
class PillButtonWidget extends StatelessWidget {
  const PillButtonWidget({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
    this.secondary = false,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final bool secondary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !loading;

    return FilledButton(
      onPressed: enabled ? onPressed : null,
      style: FilledButton.styleFrom(
        backgroundColor:
            secondary ? scheme.surfaceContainerHighest : scheme.primary,
        foregroundColor: secondary ? scheme.onSurface : scheme.onPrimary,
        disabledBackgroundColor: scheme.primary.withValues(alpha: 0.35),
        minimumSize: Size(
          expanded ? double.infinity : AppSpacing.minTapTarget,
          56,
        ),
      ),
      child: loading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: secondary ? scheme.primary : scheme.onPrimary,
              ),
            )
          : Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }
}
