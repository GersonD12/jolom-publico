import 'package:flutter/material.dart';

import 'app_radius.dart';

/// Variantes de decoración que complementan el tema global de los inputs.
abstract final class AppInputDecoration {
  /// Borde estable para campos que crecen verticalmente.
  static InputDecoration multiline(
    BuildContext context, {
    required String labelText,
  }) {
    final scheme = Theme.of(context).colorScheme;

    OutlineInputBorder border(BorderSide side) => OutlineInputBorder(
      borderRadius: AppRadius.cardCompact,
      borderSide: side,
    );

    return InputDecoration(
      labelText: labelText,
      border: border(BorderSide.none),
      enabledBorder: border(BorderSide.none),
      disabledBorder: border(BorderSide.none),
      focusedBorder: border(BorderSide(color: scheme.primary, width: 1.5)),
      errorBorder: border(BorderSide(color: scheme.error)),
      focusedErrorBorder: border(BorderSide(color: scheme.error, width: 1.5)),
    );
  }
}
