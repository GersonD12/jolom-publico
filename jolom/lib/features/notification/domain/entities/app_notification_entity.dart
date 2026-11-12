/// Notificación in-app de la bandeja.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.createdAt,
    this.deepLink,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final String? deepLink;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromMap(
    String id,
    Map<String, dynamic> map, {
    required DateTime createdAt,
    DateTime? readAt,
  }) {
    return AppNotification(
      id: id,
      type: map['type'] as String? ?? 'system',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      data: map['data'] is Map
          ? Map<String, dynamic>.from(map['data'] as Map)
          : const {},
      deepLink: map['deepLink'] as String?,
      readAt: readAt,
      createdAt: createdAt,
    );
  }
}
