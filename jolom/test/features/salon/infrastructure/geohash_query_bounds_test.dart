import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/features/salon/domain/entities/nearby_salon_entity.dart';
import 'package:jolom/features/salon/infrastructure/geohash_query_bounds.dart';

void main() {
  const guatemalaCity = GeoCoordinates(latitude: 14.6349, longitude: -90.5069);

  test('los rangos cubren el geohash del centro', () {
    final ranges = GeohashQueryBounds.forArea(
      const SalonSearchArea(center: guatemalaCity, radiusKm: 10),
    );

    expect(ranges, isNotEmpty);
    expect(ranges.length, lessThanOrEqualTo(9));
    expect(
      ranges.any(
        (range) =>
            '9fxek2nyk'.compareTo(range.start) >= 0 &&
            '9fxek2nyk'.compareTo(range.end) <= 0,
      ),
      isTrue,
    );
  });

  test('calcula distancia Haversine en kilómetros', () {
    const antiguaGuatemala = GeoCoordinates(
      latitude: 14.5586,
      longitude: -90.7295,
    );

    final distance = GeohashQueryBounds.distanceKm(
      guatemalaCity,
      antiguaGuatemala,
    );

    expect(distance, closeTo(25.4, 1));
  });

  test('rechaza coordenadas inválidas', () {
    expect(
      () => GeohashQueryBounds.forArea(
        const SalonSearchArea(
          center: GeoCoordinates(latitude: 91, longitude: 0),
          radiusKm: 5,
        ),
      ),
      throwsArgumentError,
    );
  });
}
