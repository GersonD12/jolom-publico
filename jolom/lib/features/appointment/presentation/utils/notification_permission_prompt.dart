import 'package:flutter/material.dart';
import 'package:jolom/services/fcm_service.dart';

/// Prompt de permiso de notificaciones push (cliente o negocio).
class NotificationPermissionPrompt {
  NotificationPermissionPrompt._();

  /// Si ya hay permiso, registra el token. Si no y [showDialogIfNeeded],
  /// muestra el diálogo una vez (cuando [alreadyShown] es false).
  ///
  /// Devuelve `true` si se mostró (o se intentó mostrar) el diálogo en esta
  /// llamada, para que la pantalla marque `_promptShownThisVisit`.
  static Future<bool> ensureNotificationsEnabled({
    required BuildContext context,
    required bool Function() isMounted,
    required String body,
    required bool showDialogIfNeeded,
    required bool alreadyShown,
  }) async {
    if (!isMounted()) return alreadyShown;

    final enabled = await FcmService.areNotificationsEnabled();
    if (!isMounted()) return alreadyShown;

    if (enabled) {
      await FcmService.registerTokenAfterLogin();
      return alreadyShown;
    }

    if (!showDialogIfNeeded || alreadyShown) return alreadyShown;

    await _showEnableDialog(context: context, isMounted: isMounted, body: body);
    return true;
  }

  static Future<void> _showEnableDialog({
    required BuildContext context,
    required bool Function() isMounted,
    required String body,
  }) async {
    if (!isMounted()) return;
    final activate = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Activa las notificaciones'),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Activar'),
          ),
        ],
      ),
    );
    if (activate != true || !isMounted()) return;

    // Intenta el diálogo del sistema; si ya estaba denegado, abre Ajustes.
    await FcmService.registerTokenAfterLogin();
    if (!isMounted()) return;
    if (await FcmService.areNotificationsEnabled()) return;

    await FcmService.openSystemNotificationSettings();
  }
}
