import 'dart:math' as math;

import '../domain/entities/nearby_salon_entity.dart';

/// Rango lexicográfico para una consulta sobre el campo `geohash`.
class GeohashRange {
  const GeohashRange(this.start, this.end);

  final String start;
  final String end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeohashRange && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Port del algoritmo GeoFire recomendado por Firebase para geoqueries.
abstract final class GeohashQueryBounds {
  static const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
  static const _earthMeridionalCircumference = 40007860.0;
  static const _metersPerDegreeLatitude = 110574.0;
  static const _bitsPerChar = 5;
  static const _maximumBitsPrecision = 22 * _bitsPerChar;
  static const _earthEquatorialRadius = 6378137.0;
  static const _eccentricitySquared = 0.00669447819799;
  static const _epsilon = 1e-12;

  /// Devuelve los rangos que contienen el círculo solicitado (máximo nueve).
  static List<GeohashRange> forArea(SalonSearchArea area) {
    final center = area.center;
    if (!center.isValid) {
      throw ArgumentError('Coordenadas fuera de rango.');
    }
    final radiusMeters = area.radiusKm * 1000;
    if (!radiusMeters.isFinite || radiusMeters <= 0) {
      throw ArgumentError('El radio debe ser mayor que cero.');
    }

    final queryBits = math.max(1, _boundingBoxBits(center, radiusMeters));
    final precision = (queryBits / _bitsPerChar).ceil();
    final unique = <GeohashRange>{};
    for (final coordinate in _boundingBoxCoordinates(center, radiusMeters)) {
      unique.add(_query(_encode(coordinate, precision), queryBits));
    }
    return unique.toList(growable: false);
  }

  /// Distancia Haversine aproximada en kilómetros.
  static double distanceKm(GeoCoordinates from, GeoCoordinates to) =>
      from.distanceToKm(to);

  static double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  static double _metersToLongitudeDegrees(double distance, double latitude) {
    final radians = _degreesToRadians(latitude);
    final numerator =
        math.cos(radians) * _earthEquatorialRadius * math.pi / 180;
    final denominator =
        1 /
        math.sqrt(
          1 - _eccentricitySquared * math.sin(radians) * math.sin(radians),
        );
    final deltaDegrees = numerator * denominator;
    if (deltaDegrees < _epsilon) return distance > 0 ? 360.0 : 0.0;
    return math.min(360.0, distance / deltaDegrees);
  }

  static double _longitudeBitsForResolution(
    double resolution,
    double latitude,
  ) {
    final degrees = _metersToLongitudeDegrees(resolution, latitude);
    return degrees.abs() > 0.000001 ? math.max(1.0, _log2(360 / degrees)) : 1.0;
  }

  static double _latitudeBitsForResolution(double resolution) => math.min(
    _log2(_earthMeridionalCircumference / 2 / resolution),
    _maximumBitsPrecision.toDouble(),
  );

  static double _log2(double value) => math.log(value) / math.log(2);

  static int _boundingBoxBits(GeoCoordinates center, double size) {
    final latDeltaDegrees = size / _metersPerDegreeLatitude;
    final latitudeNorth = math.min(90.0, center.latitude + latDeltaDegrees);
    final latitudeSouth = math.max(-90.0, center.latitude - latDeltaDegrees);
    final bitsLatitude = _latitudeBitsForResolution(size).floor() * 2;
    final bitsLongitudeNorth =
        _longitudeBitsForResolution(size, latitudeNorth).floor() * 2 - 1;
    final bitsLongitudeSouth =
        _longitudeBitsForResolution(size, latitudeSouth).floor() * 2 - 1;
    return math.min(
      math.min(bitsLatitude, bitsLongitudeNorth),
      math.min(bitsLongitudeSouth, _maximumBitsPrecision),
    );
  }

  static List<GeoCoordinates> _boundingBoxCoordinates(
    GeoCoordinates center,
    double radius,
  ) {
    final latitudeDegrees = radius / _metersPerDegreeLatitude;
    final latitudeNorth = math.min(90.0, center.latitude + latitudeDegrees);
    final latitudeSouth = math.max(-90.0, center.latitude - latitudeDegrees);
    final longitudeDegrees = math.max(
      _metersToLongitudeDegrees(radius, latitudeNorth),
      _metersToLongitudeDegrees(radius, latitudeSouth),
    );
    final west = _wrapLongitude(center.longitude - longitudeDegrees);
    final east = _wrapLongitude(center.longitude + longitudeDegrees);
    return [
      center,
      GeoCoordinates(latitude: center.latitude, longitude: west),
      GeoCoordinates(latitude: center.latitude, longitude: east),
      GeoCoordinates(latitude: latitudeNorth, longitude: center.longitude),
      GeoCoordinates(latitude: latitudeNorth, longitude: west),
      GeoCoordinates(latitude: latitudeNorth, longitude: east),
      GeoCoordinates(latitude: latitudeSouth, longitude: center.longitude),
      GeoCoordinates(latitude: latitudeSouth, longitude: west),
      GeoCoordinates(latitude: latitudeSouth, longitude: east),
    ];
  }

  static double _wrapLongitude(double longitude) {
    if (longitude >= -180 && longitude <= 180) return longitude;
    final adjusted = longitude + 180;
    return adjusted > 0 ? (adjusted % 360) - 180 : 180 - ((-adjusted) % 360);
  }

  static String _encode(GeoCoordinates location, int precision) {
    var latitudeMin = -90.0;
    var latitudeMax = 90.0;
    var longitudeMin = -180.0;
    var longitudeMax = 180.0;
    var hash = '';
    var hashValue = 0;
    var bits = 0;
    var even = true;

    while (hash.length < precision) {
      final value = even ? location.longitude : location.latitude;
      final min = even ? longitudeMin : latitudeMin;
      final max = even ? longitudeMax : latitudeMax;
      final middle = (min + max) / 2;
      hashValue <<= 1;
      if (value > middle) {
        hashValue += 1;
        if (even) {
          longitudeMin = middle;
        } else {
          latitudeMin = middle;
        }
      } else if (even) {
        longitudeMax = middle;
      } else {
        latitudeMax = middle;
      }

      even = !even;
      if (bits < 4) {
        bits += 1;
      } else {
        bits = 0;
        hash += _base32[hashValue];
        hashValue = 0;
      }
    }
    return hash;
  }

  static GeohashRange _query(String geohash, int bits) {
    final precision = (bits / _bitsPerChar).ceil();
    if (geohash.length < precision) return GeohashRange(geohash, '$geohash~');
    final truncated = geohash.substring(0, precision);
    final base = truncated.substring(0, truncated.length - 1);
    final lastValue = _base32.indexOf(truncated[truncated.length - 1]);
    final significantBits = bits - base.length * _bitsPerChar;
    final unusedBits = _bitsPerChar - significantBits;
    final startValue = (lastValue >> unusedBits) << unusedBits;
    final endValue = startValue + (1 << unusedBits);
    return GeohashRange(
      '$base${_base32[startValue]}',
      endValue > 31 ? '$base~' : '$base${_base32[endValue]}',
    );
  }
}
