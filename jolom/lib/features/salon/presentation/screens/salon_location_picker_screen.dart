import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/theme/theme.dart';

import '../../domain/entities/nearby_salon_entity.dart';
import '../controllers/device_location_controller.dart';
import '../widgets/current_location_indicator_widget.dart';

/// Permite posicionar un pin sin depender de geocodificación ni Places.
class SalonLocationPickerScreen extends StatefulWidget {
  const SalonLocationPickerScreen({this.initialCoordinates, super.key});

  final GeoCoordinates? initialCoordinates;

  @override
  State<SalonLocationPickerScreen> createState() =>
      _SalonLocationPickerScreenState();
}

class _SalonLocationPickerScreenState extends State<SalonLocationPickerScreen> {
  static const _guatemalaCity = GeoCoordinates(
    latitude: 14.6349,
    longitude: -90.5069,
  );

  GoogleMapController? _mapController;
  late GeoCoordinates _selected;
  bool _locating = false;
  bool _showUserLocation = false;
  bool _locationPromptShownThisVisit = false;
  bool _recheckLocationOnResume = false;
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onResume: _onAppResumed);
    _selected = widget.initialCoordinates ?? _guatemalaCity;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_ensureLocationOnEntry());
    });
  }

  void _onAppResumed() {
    if (!_recheckLocationOnResume) return;
    _recheckLocationOnResume = false;
    unawaited(_recheckLocationAfterSettings());
  }

  Future<void> _ensureLocationOnEntry() async {
    final access = await DeviceLocationController.checkAccess();
    if (!mounted) return;

    if (access == DeviceLocationAccess.ready) {
      await _useCurrentLocation();
      return;
    }
    if (_locationPromptShownThisVisit) return;
    _locationPromptShownThisVisit = true;

    final activate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Activa tu ubicación'),
        content: const Text(
          'Jolom usa tu ubicación como punto de partida para que puedas '
          'ajustar con precisión la entrada de tu negocio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              access == DeviceLocationAccess.permissionDenied
                  ? 'Continuar'
                  : 'Abrir ajustes',
            ),
          ),
        ],
      ),
    );
    if (activate != true || !mounted) return;

    switch (access) {
      case DeviceLocationAccess.ready:
        await _useCurrentLocation();
      case DeviceLocationAccess.permissionDenied:
        await _useCurrentLocation();
      case DeviceLocationAccess.serviceDisabled:
        _recheckLocationOnResume = true;
        await DeviceLocationController.openLocationSettings();
      case DeviceLocationAccess.permissionDeniedForever:
        _recheckLocationOnResume = true;
        await DeviceLocationController.openAppSettings();
    }
  }

  Future<void> _recheckLocationAfterSettings() async {
    final access = await DeviceLocationController.checkAccess();
    if (!mounted) return;
    if (access == DeviceLocationAccess.ready ||
        access == DeviceLocationAccess.permissionDenied) {
      await _useCurrentLocation();
    }
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final coordinates =
          await DeviceLocationController.getCurrentCoordinates();
      if (!mounted) return;
      setState(() {
        _selected = coordinates;
        _showUserLocation = true;
      });
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(coordinates.latitude, coordinates.longitude),
          17,
        ),
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(error, stackTrace))),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _handleMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (!_showUserLocation) return;
    unawaited(
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_selected.latitude, _selected.longitude),
          17,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ubicación de la peluquería')),
      body: Stack(
        alignment: Alignment.center,
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_selected.latitude, _selected.longitude),
              zoom: widget.initialCoordinates == null ? 13 : 17,
            ),
            mapToolbarEnabled: false,
            myLocationEnabled: _showUserLocation,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: _handleMapCreated,
            onCameraMove: (position) {
              _selected = GeoCoordinates(
                latitude: position.target.latitude,
                longitude: position.target.longitude,
              );
            },
          ),
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.location_pin,
                    size: 60,
                    color: Colors.white,
                    shadows: [Shadow(color: Color(0x88000000), blurRadius: 10)],
                  ),
                  Icon(Icons.location_pin, size: 52, color: scheme.primary),
                ],
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: SafeArea(
              bottom: false,
              child: Material(
                elevation: 2,
                color: scheme.surface,
                borderRadius: AppRadius.cardCompact,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.location_pin,
                            size: 34,
                            color: Colors.white,
                            shadows: [
                              Shadow(color: Color(0x66000000), blurRadius: 6),
                            ],
                          ),
                          Icon(
                            Icons.location_pin,
                            size: 30,
                            color: scheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Mueve el mapa hasta dejar el pin sobre la entrada del negocio.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 48,
                      child: FloatingActionButton.small(
                        heroTag: 'salon-location',
                        onPressed: _locating ? null : _useCurrentLocation,
                        tooltip: 'Usar mi ubicación',
                        child: const CurrentLocationIndicatorWidget(
                          dimension: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(_selected),
                        icon: const Icon(Icons.check),
                        label: const Text('Confirmar ubicación'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_locating) ...[
            const ModalBarrier(dismissible: false, color: Colors.black38),
            const AlertDialog(
              content: Row(
                children: [
                  SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Localizando…'),
                        SizedBox(height: AppSpacing.xs),
                        Text('Estamos obteniendo tu ubicación actual.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
