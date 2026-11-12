import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jolom/core/theme/theme.dart';

/// Fondo ambiental con masas de color que fluyen como una lámpara de lava.
class AmbientBackgroundWidget extends StatefulWidget {
  const AmbientBackgroundWidget({
    required this.child,
    this.gradient,
    super.key,
  });

  final Widget child;
  final Gradient? gradient;

  @override
  State<AmbientBackgroundWidget> createState() =>
      _AmbientBackgroundWidgetState();
}

class _AmbientBackgroundWidgetState extends State<AmbientBackgroundWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _lavaController;

  @override
  void initState() {
    super.initState();
    _lavaController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduceMotion(context)) {
      _lavaController.stop();
      _lavaController.value = 0;
    } else if (!_lavaController.isAnimating) {
      _lavaController.repeat();
    }
  }

  @override
  void dispose() {
    _lavaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final softUi = SoftUiTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final colors = [
      colorScheme.primaryContainer,
      colorScheme.secondaryContainer,
      colorScheme.tertiaryContainer,
      colorScheme.primary,
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: widget.gradient ?? softUi.ambientGradient,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _LavaLampPainter(
                  animation: _lavaController,
                  colors: colors,
                  isDark: isDark,
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// Dibuja óvalos difusos en trayectorias distintas para crear profundidad.
///
/// El painter se repinta directamente desde el controller para no reconstruir
/// el contenido de la pantalla en cada frame.
class _LavaLampPainter extends CustomPainter {
  _LavaLampPainter({
    required this.animation,
    required this.colors,
    required this.isDark,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<Color> colors;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final turn = animation.value * math.pi * 2;
    final shortestSide = size.shortestSide;

    _paintBlob(
      canvas,
      center: Offset(
        size.width * (0.18 + 0.16 * math.sin(turn)),
        size.height * (0.14 + 0.12 * math.cos(turn * 2)),
      ),
      width: shortestSide * 1.08,
      height: shortestSide * 0.82,
      rotation: 0.18 * math.sin(turn),
      color: colors[0],
      opacity: isDark ? 0.42 : 0.68,
    );
    _paintBlob(
      canvas,
      center: Offset(
        size.width * (0.82 + 0.14 * math.cos(turn + 0.4)),
        size.height * (0.30 + 0.18 * math.sin(turn * 2 + 0.2)),
      ),
      width: shortestSide * 0.88,
      height: shortestSide * 1.18,
      rotation: -0.14 * math.sin(turn + 1.1),
      color: colors[1],
      opacity: isDark ? 0.34 : 0.52,
    );
    _paintBlob(
      canvas,
      center: Offset(
        size.width * (0.30 + 0.20 * math.cos(turn + 1.3)),
        size.height * (0.70 + 0.16 * math.sin(turn * 2 + 0.8)),
      ),
      width: shortestSide * 1.15,
      height: shortestSide * 0.72,
      rotation: 0.4 + 0.12 * math.sin(turn * 2 + 0.4),
      color: colors[2],
      opacity: isDark ? 0.30 : 0.48,
    );
    _paintBlob(
      canvas,
      center: Offset(
        size.width * (0.74 + 0.18 * math.sin(turn * 2 + 2.1)),
        size.height * (0.86 + 0.10 * math.cos(turn + 1.7)),
      ),
      width: shortestSide * 0.74,
      height: shortestSide * 0.96,
      rotation: -0.25 + 0.16 * math.sin(turn + 0.6),
      color: colors[3],
      opacity: isDark ? 0.22 : 0.20,
    );
  }

  void _paintBlob(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
    required double rotation,
    required Color color,
    required double opacity,
  }) {
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: height,
    );
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.18, -0.22),
        radius: 0.82,
        colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: opacity * 0.68),
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.48, 1],
      ).createShader(rect);

    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(rotation)
      ..drawOval(rect, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(covariant _LavaLampPainter oldDelegate) {
    return oldDelegate.colors != colors || oldDelegate.isDark != isDark;
  }
}
