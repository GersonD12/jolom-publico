import '../../domain/entities/nearby_salon_entity.dart';

/// Evita repetir geo-consultas mientras el mapa siga cerca del último centro.
abstract final class SalonExploreSearchPolicy {
  static const minimumMovementKm = 1.5;
  static const maximumReuseAge = Duration(seconds: 30);
  static const minimumMovementAfterExpiryKm = 0.005;

  static bool shouldRefresh({
    required GeoCoordinates lastQueryCenter,
    required GeoCoordinates candidateCenter,
    required Duration timeSinceLastQuery,
  }) {
    final distanceKm = lastQueryCenter.distanceToKm(candidateCenter);
    if (distanceKm > minimumMovementKm) return true;
    return timeSinceLastQuery >= maximumReuseAge &&
        distanceKm >= minimumMovementAfterExpiryKm;
  }
}
