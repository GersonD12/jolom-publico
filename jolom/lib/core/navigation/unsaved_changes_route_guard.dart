import 'package:flutter/material.dart';
import 'package:jolom/shared/widgets/discard_unsaved_changes_dialog.dart';

/// Protege una salida voluntaria sin interferir con redirects obligatorios.
class UnsavedChangesRouteGuard {
  Future<bool>? _pendingConfirmation;

  Future<bool> canExit({
    required BuildContext context,
    required bool canRemainInRoute,
    required bool hasUnsavedChanges,
    required VoidCallback clearUnsavedChanges,
  }) async {
    if (!canRemainInRoute) {
      if (_pendingConfirmation != null) {
        Navigator.of(context, rootNavigator: true).pop(false);
      }
      clearUnsavedChanges();
      return true;
    }
    if (!hasUnsavedChanges) return true;

    final confirmation = _pendingConfirmation ??=
        showDiscardUnsavedChangesDialog(context);
    try {
      final discard = await confirmation;
      if (discard) clearUnsavedChanges();
      return discard;
    } finally {
      if (identical(_pendingConfirmation, confirmation)) {
        _pendingConfirmation = null;
      }
    }
  }
}
