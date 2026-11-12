import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/providers/shared_preferences_provider.dart';

import '../../domain/entities/nearby_salon_entity.dart';

const _locationKey = 'salon_explore_last_location';

/// Última ubicación GPS válida, persistida únicamente en este dispositivo.
class LastExploreLocationNotifier extends Notifier<GeoCoordinates?> {
  @override
  GeoCoordinates? build() {
    final preferences = ref.watch(sharedPreferencesProvider);
    final stored = preferences.getString(_locationKey);
    if (stored == null) return null;
    final parts = stored.split(',');
    if (parts.length != 2) return null;
    final latitude = double.tryParse(parts[0]);
    final longitude = double.tryParse(parts[1]);
    if (latitude == null || longitude == null) return null;
    final coordinates = GeoCoordinates(
      latitude: latitude,
      longitude: longitude,
    );
    return coordinates.isValid ? coordinates : null;
  }

  Future<void> save(GeoCoordinates coordinates) async {
    if (!coordinates.isValid) return;
    state = coordinates;
    final preferences = ref.read(sharedPreferencesProvider);
    await preferences.setString(
      _locationKey,
      '${coordinates.latitude},${coordinates.longitude}',
    );
  }
}

final lastExploreLocationProvider =
    NotifierProvider<LastExploreLocationNotifier, GeoCoordinates?>(
      LastExploreLocationNotifier.new,
    );
