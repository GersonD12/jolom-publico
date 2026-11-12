import 'package:flutter/material.dart';

/// Radios de borde Soft UI (tarjetas orgánicas y píldoras).
abstract final class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 28;
  static const double full = 999;

  static final BorderRadius card = BorderRadius.circular(xl);
  static final BorderRadius cardLarge = BorderRadius.circular(xxl);
  static final BorderRadius cardCompact = BorderRadius.circular(lg);
  static final BorderRadius pill = BorderRadius.circular(full);
  static final BorderRadius chip = BorderRadius.circular(full);
  static final BorderRadius navBar = BorderRadius.circular(full);
  static final BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xxl),
  );
}
