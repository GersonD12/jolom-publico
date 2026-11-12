import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jolom/core/theme/app_spacing.dart';

/// Menú (64 px) + separación visual (16 px) para acciones al final de un scroll.
const double appBottomActionClearance = 80;

/// Distancia inferior para mensajes, tarjetas y acciones flotantes.
///
/// El `Scaffold` principal comunica en [MediaQuery.padding] la altura de la
/// navegación superpuesta. Al usar esta función, un overlay queda por encima
/// tanto de ese menú como del área segura física del dispositivo.
double appBottomOverlayInset(
  BuildContext context, {
  double spacing = AppSpacing.md,
}) {
  final shellBottomInset = MediaQuery.paddingOf(context).bottom;
  final physicalBottomInset = MediaQuery.viewPaddingOf(context).bottom;

  return math.max(shellBottomInset, physicalBottomInset) + spacing;
}

/// Padding mínimo para contenido desplazable bajo la navegación auto-ocultable.
///
/// `MediaQuery.padding` incluye el espacio que el shell comunica para su barra.
/// Solo se agrega al final del scroll, por lo que el contenido sigue pasando
/// por debajo de la superficie translúcida mientras se desplaza.
EdgeInsets appScrollPadding(
  BuildContext context, {
  required double horizontal,
  required double vertical,
  double? bottom,
}) {
  final shellBottomInset = MediaQuery.paddingOf(context).bottom;
  final physicalBottomInset = MediaQuery.viewPaddingOf(context).bottom;
  final bottomPadding = math.max(
    shellBottomInset + vertical,
    physicalBottomInset + (bottom ?? vertical),
  );

  return EdgeInsets.fromLTRB(horizontal, vertical, horizontal, bottomPadding);
}
