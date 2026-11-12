import 'package:flutter/material.dart';
import 'package:jolom/core/theme/theme.dart';

/// Escala sutil al presionar; respeta reducción de movimiento.
class PressableScaleWidget extends StatefulWidget {
  const PressableScaleWidget({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.scale = AppMotion.pressScale,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final double scale;

  @override
  State<PressableScaleWidget> createState() => _PressableScaleWidgetState();
}

class _PressableScaleWidgetState extends State<PressableScaleWidget> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.durationOf(context, AppMotion.fast);
    final curve = AppMotion.curveOf(context, AppMotion.decelerate);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onTap : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: duration,
        curve: curve,
        child: widget.child,
      ),
    );
  }
}
