import 'package:geolocator/geolocator.dart';

import '../../domain/entities/nearby_salon_entity.dart';

enum DeviceLocationAccess {
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

/// Centraliza permisos y lectura puntual de la ubicación del dispositivo.
abstract final class DeviceLocationController {
  static Future<DeviceLocationAccess> checkAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return DeviceLocationAccess.serviceDisabled;
    }

    final permission = await Geolocator.checkPermission();
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => DeviceLocationAccess.ready,
      LocationPermission.deniedForever =>
        DeviceLocationAccess.permissionDeniedForever,
      LocationPermission.denied || LocationPermission.unableToDetermine =>
        DeviceLocationAccess.permissionDenied,
    };
  }

  /// Indica si el punto azul puede mostrarse sin solicitar permisos nuevos.
  static Future<bool> canShowCurrentLocation() async {
    return await checkAccess() == DeviceLocationAccess.ready;
  }

  static Future<bool> openLocationSettings() =>
      Geolocator.openLocationSettings();

  static Future<bool> openAppSettings() => Geolocator.openAppSettings();

  static Future<GeoCoordinates> getCurrentCoordinates() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('Activa el GPS del dispositivo para usar tu ubicación.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw StateError('Se necesita permiso de ubicación.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError(
        'El permiso de ubicación está bloqueado. Actívalo en Ajustes.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return GeoCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
