import 'package:flutter/material.dart';
import 'package:jolom/core/theme/theme.dart';

/// Entrada con fade + desplazamiento vertical (180–300 ms).
class FadeSlideInWidget extends StatelessWidget {
  const FadeSlideInWidget({
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.normal,
    this.offset = AppMotion.entranceOffset,
    this.curve = AppMotion.standard,
    super.key,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Interval(
        delay.inMilliseconds / (duration + delay).inMilliseconds,
        1,
        curve: curve,
      ),
      builder: (context, value, child) {
        return IgnorePointer(
          ignoring: value < 1.0,
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, offset * (1 - value)),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}
