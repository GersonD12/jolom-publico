import 'dart:math' as math;

import 'salon_entity.dart';

/// Coordenada geográfica independiente de Firebase y del proveedor de mapas.
class GeoCoordinates {
  const GeoCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  /// Distancia Haversine aproximada hasta [other], expresada en kilómetros.
  double distanceToKm(GeoCoordinates other) {
    if (!isValid || !other.isValid) {
      throw ArgumentError('Coordenadas fuera de rango.');
    }
    const earthRadiusKm = 6371.0;
    double toRadians(double degrees) => degrees * math.pi / 180;
    final latDelta = toRadians(other.latitude - latitude);
    final lonDelta = toRadians(other.longitude - longitude);
    final fromLat = toRadians(latitude);
    final toLat = toRadians(other.latitude);
    final a =
        math.sin(latDelta / 2) * math.sin(latDelta / 2) +
        math.cos(fromLat) *
            math.cos(toLat) *
            math.sin(lonDelta / 2) *
            math.sin(lonDelta / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoCoordinates &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// Área circular usada para descubrir peluquerías cercanas.
class SalonSearchArea {
  const SalonSearchArea({required this.center, required this.radiusKm});

  final GeoCoordinates center;
  final double radiusKm;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalonSearchArea &&
          center == other.center &&
          radiusKm == other.radiusKm;

  @override
  int get hashCode => Object.hash(center, radiusKm);
}

/// Peluquería encontrada dentro de un radio, con distancia ya calculada.
class NearbySalon {
  const NearbySalon({required this.salon, required this.distanceKm});

  final Salon salon;
  final double distanceKm;
}
