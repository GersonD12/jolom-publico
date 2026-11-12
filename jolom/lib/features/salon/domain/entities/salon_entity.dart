/// Estado de publicación de una peluquería.
enum SalonPublishStatus {
  draft,
  published,
  hidden,
  suspended,
  deleted,
}

/// Etiqueta en español para UI (el valor en Firestore sigue en inglés).
extension SalonPublishStatusLabel on SalonPublishStatus {
  String get labelEs => switch (this) {
    SalonPublishStatus.draft => 'Borrador',
    SalonPublishStatus.published => 'Publicado',
    SalonPublishStatus.hidden => 'Oculto',
    SalonPublishStatus.suspended => 'Suspendido',
    SalonPublishStatus.deleted => 'Eliminado',
  };
}

/// Ficha de peluquería.
class Salon {
  const Salon({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.city,
    required this.currency,
    required this.timeZone,
    required this.publishStatus,
    this.description,
    this.contactPhone,
    this.contactEmail,
    this.address,
    this.latitude,
    this.longitude,
    this.geohash,
    this.coverImageUrl,
    this.imageUrls = const [],
    this.isDeleted = false,
  });

  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? contactPhone;
  final String? contactEmail;
  final String? address;
  /// Latitud del GeoPoint `location` (null si no hay GPS guardado).
  final double? latitude;
  /// Longitud del GeoPoint `location` (null si no hay GPS guardado).
  final double? longitude;
  /// Geohash de precisión 9 (escrito por `updateSalon`).
  final String? geohash;
  final String city;
  final String currency;
  final String timeZone;
  final SalonPublishStatus publishStatus;
  /// Thumb WebP de la primera foto del lugar (carga rápida).
  final String? coverImageUrl;
  /// Hasta 10 URLs WebP completas del lugar (índice 0 = principal).
  final List<String> imageUrls;
  final bool isDeleted;

  /// True si hay coordenadas GPS persistidas.
  bool get hasLocation => latitude != null && longitude != null;

  factory Salon.fromMap(String id, Map<String, dynamic> map) {
    final rawUrls = map['imageUrls'];
    final imageUrls = rawUrls is List
        ? rawUrls.whereType<String>().where((u) => u.isNotEmpty).toList()
        : <String>[];
    final coords = _parseLocation(map['location']);
    return Salon(
      id: id,
      ownerId: map['ownerId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      contactPhone: map['contactPhone'] as String?,
      contactEmail: map['contactEmail'] as String?,
      address: map['address'] as String?,
      latitude: coords.$1,
      longitude: coords.$2,
      geohash: map['geohash'] as String?,
      city: map['city'] as String? ?? 'Guatemala',
      currency: map['currency'] as String? ?? 'GTQ',
      timeZone: map['timeZone'] as String? ?? 'America/Guatemala',
      publishStatus: _parsePublishStatus(map['publishStatus'] as String?),
      coverImageUrl: map['coverImageUrl'] as String?,
      imageUrls: imageUrls,
      isDeleted: map['isDeleted'] as bool? ?? false,
    );
  }

  /// Extrae lat/lng de un GeoPoint de Firestore sin acoplar el tipo al dominio.
  static (double?, double?) _parseLocation(dynamic raw) {
    if (raw == null) return (null, null);
    try {
      final lat = (raw as dynamic).latitude;
      final lng = (raw as dynamic).longitude;
      if (lat is num && lng is num) {
        return (lat.toDouble(), lng.toDouble());
      }
    } catch (_) {
      // Ignorar formatos inesperados.
    }
    return (null, null);
  }

  static SalonPublishStatus _parsePublishStatus(String? value) {
    return SalonPublishStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SalonPublishStatus.draft,
    );
  }
}
