import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/features/salon/domain/entities/nearby_salon_entity.dart';
import 'package:jolom/features/salon/presentation/controllers/salon_explore_search_policy.dart';

void main() {
  const lastQueryCenter = GeoCoordinates(
    latitude: 14.6349,
    longitude: -90.5069,
  );

  test('no consulta de nuevo cuando el centro se mueve menos de 1.5 km', () {
    const nearbyCenter = GeoCoordinates(latitude: 14.6449, longitude: -90.5069);

    expect(
      SalonExploreSearchPolicy.shouldRefresh(
        lastQueryCenter: lastQueryCenter,
        candidateCenter: nearbyCenter,
        timeSinceLastQuery: const Duration(seconds: 20),
      ),
      isFalse,
    );
  });

  test('consulta de nuevo cuando el centro se mueve más de 1.5 km', () {
    const distantCenter = GeoCoordinates(
      latitude: 14.6549,
      longitude: -90.5069,
    );

    expect(
      SalonExploreSearchPolicy.shouldRefresh(
        lastQueryCenter: lastQueryCenter,
        candidateCenter: distantCenter,
        timeSinceLastQuery: const Duration(seconds: 20),
      ),
      isTrue,
    );
  });

  test('después de 30 segundos consulta con un movimiento pequeño', () {
    const slightlyMovedCenter = GeoCoordinates(
      latitude: 14.63496,
      longitude: -90.5069,
    );

    expect(
      SalonExploreSearchPolicy.shouldRefresh(
        lastQueryCenter: lastQueryCenter,
        candidateCenter: slightlyMovedCenter,
        timeSinceLastQuery: const Duration(seconds: 30),
      ),
      isTrue,
    );
  });

  test('después de 30 segundos ignora movimientos menores de 5 metros', () {
    const jitteredCenter = GeoCoordinates(
      latitude: 14.63494,
      longitude: -90.5069,
    );

    expect(
      SalonExploreSearchPolicy.shouldRefresh(
        lastQueryCenter: lastQueryCenter,
        candidateCenter: jitteredCenter,
        timeSinceLastQuery: const Duration(seconds: 30),
      ),
      isFalse,
    );
  });

  test('después de 30 segundos no consulta sin movimiento real', () {
    expect(
      SalonExploreSearchPolicy.shouldRefresh(
        lastQueryCenter: lastQueryCenter,
        candidateCenter: lastQueryCenter,
        timeSinceLastQuery: const Duration(seconds: 30),
      ),
      isFalse,
    );
  });
}
