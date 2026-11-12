import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jolom/core/infrastructure/firestore_date_utils.dart';
import 'package:jolom/features/notification/domain/entities/app_notification_entity.dart';
import 'package:jolom/features/notification/domain/repositories/notification_repository.dart';

/// Lectura de bandeja `notifications/{uid}/items`.
class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _items(String userId) {
    return _db.collection('notifications').doc(userId).collection('items');
  }

  @override
  Stream<List<AppNotification>> watchNotifications(
    String userId, {
    int limit = 50,
  }) {
    return _items(userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final data = d.data();
            return AppNotification.fromMap(
              d.id,
              data,
              createdAt: requireFirestoreDate(data['createdAt']),
              readAt: parseFirestoreDate(data['readAt']),
            );
          }).toList(),
        );
  }

  @override
  Future<void> markAsRead(String userId, String notificationId) async {
    await _items(userId).doc(notificationId).update({
      'readAt': FieldValue.serverTimestamp(),
    });
  }
}
