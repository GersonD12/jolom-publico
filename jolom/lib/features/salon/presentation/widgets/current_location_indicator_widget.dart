import 'package:flutter/material.dart';

/// Punto azul de ubicación con un pulso visual delicado.
class CurrentLocationIndicatorWidget extends StatefulWidget {
  const CurrentLocationIndicatorWidget({this.dimension = 24, super.key});

  final double dimension;

  @override
  State<CurrentLocationIndicatorWidget> createState() =>
      _CurrentLocationIndicatorWidgetState();
}

class _CurrentLocationIndicatorWidgetState
    extends State<CurrentLocationIndicatorWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _controller
        ..stop()
        ..value = 0.35;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.dimension,
    child: Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => Transform.scale(
            scale: 0.82 + (_pulse.value * 0.42),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(
                  0xFF4285F4,
                ).withValues(alpha: 0.32 - (_pulse.value * 0.14)),
              ),
              child: SizedBox.square(dimension: widget.dimension),
            ),
          ),
        ),
        Container(
          width: widget.dimension * 2 / 3,
          height: widget.dimension * 2 / 3,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF4285F4),
            border: Border.all(
              color: Colors.white,
              width: widget.dimension / 8,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), blurRadius: 3),
            ],
          ),
        ),
      ],
    ),
  );
}
