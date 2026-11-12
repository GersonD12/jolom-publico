/// Servicio reservable de una peluquería.
class Service {
  const Service({
    required this.id,
    required this.salonId,
    required this.name,
    required this.durationMinutes,
    required this.price,
    required this.currency,
    required this.enabledBarberIds,
    required this.status,
    this.description,
    this.isDeleted = false,
  });

  final String id;
  final String salonId;
  final String name;
  final String? description;
  final int durationMinutes;
  final double price;
  final String currency;
  final List<String> enabledBarberIds;
  final String status;
  final bool isDeleted;

  bool get isActive => status == 'active' && !isDeleted;

  /// Etiqueta en español para UI (el valor en Firestore sigue en inglés).
  String get statusLabelEs => switch (status) {
    'active' => 'Activo',
    'inactive' => 'Inactivo',
    _ => status,
  };

  factory Service.fromMap(String id, Map<String, dynamic> map) {
    final rawIds = map['enabledBarberIds'];
    return Service(
      id: id,
      salonId: map['salonId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      currency: map['currency'] as String? ?? 'GTQ',
      enabledBarberIds: rawIds is List
          ? rawIds.map((e) => e.toString()).toList()
          : const [],
      status: map['status'] as String? ?? 'inactive',
      isDeleted: map['isDeleted'] as bool? ?? false,
    );
  }
}
