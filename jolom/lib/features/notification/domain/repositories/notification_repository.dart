import '../entities/app_notification_entity.dart';

/// Contrato de bandeja de notificaciones in-app.
abstract class NotificationRepository {
  Stream<List<AppNotification>> watchNotifications(String userId, {int limit = 50});

  Future<void> markAsRead(String userId, String notificationId);
}
