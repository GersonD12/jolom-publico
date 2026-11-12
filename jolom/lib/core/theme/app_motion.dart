import 'package:flutter/material.dart';

/// Duraciones y curvas de movimiento (180–300 ms, con propósito).
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 300);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
  static const Curve decelerate = Curves.easeOut;

  /// Escala al presionar botones y tarjetas.
  static const double pressScale = 0.97;

  /// Desplazamiento vertical de entrada (fade + slide).
  static const double entranceOffset = 12;

  /// Respetar “reducir movimiento” del sistema.
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.of(context).disableAnimations;

  static Duration durationOf(BuildContext context, Duration preferred) =>
      reduceMotion(context) ? Duration.zero : preferred;

  static Curve curveOf(BuildContext context, Curve preferred) =>
      reduceMotion(context) ? Curves.linear : preferred;
}
