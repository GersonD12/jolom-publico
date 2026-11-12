import 'package:flutter/material.dart';
import 'package:jolom/shared/widgets/pill_button_widget.dart';

/// Botón de guardar con pulso suave cuando [pulse] es true.
class PulsingSaveButtonWidget extends StatefulWidget {
  const PulsingSaveButtonWidget({
    required this.label,
    required this.onPressed,
    required this.pulse,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool pulse;
  final bool loading;

  @override
  State<PulsingSaveButtonWidget> createState() =>
      _PulsingSaveButtonWidgetState();
}

class _PulsingSaveButtonWidgetState extends State<PulsingSaveButtonWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant PulsingSaveButtonWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulse != widget.pulse) {
      _syncPulse();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _syncPulse() {
    if (widget.pulse) {
      if (!_pulseCtrl.isAnimating) {
        _pulseCtrl.repeat(reverse: true);
      }
    } else {
      _pulseCtrl
        ..stop()
        ..value = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        if (!widget.pulse) return child!;
        final t = Curves.easeInOut.transform(_pulseCtrl.value);
        final scheme = Theme.of(context).colorScheme;
        return Transform.scale(
          scale: 0.98 + 0.03 * t,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.12 + 0.2 * t),
                  blurRadius: 4 + 8 * t,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Opacity(opacity: 0.72 + 0.28 * t, child: child),
          ),
        );
      },
      child: PillButtonWidget(
        label: widget.label,
        loading: widget.loading,
        onPressed: widget.onPressed,
      ),
    );
  }
}
