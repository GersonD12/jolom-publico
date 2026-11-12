import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';

import '../../domain/entities/nearby_salon_entity.dart';
import '../controllers/device_location_controller.dart';
import '../controllers/salon_explore_search_policy.dart';
import '../controllers/salon_map_marker_controller.dart';
import '../providers/last_explore_location_provider.dart';
import '../providers/nearby_salons_provider.dart';
import 'salon_image_widget.dart';
import 'salon_map_business_carousel_widget.dart';
import 'salon_map_controls_widget.dart';
import 'salon_map_message_widget.dart';
import 'salon_map_selected_business_preview_widget.dart';

/// Mapa de peluquerías cercanas y toda su interacción efímera.
class SalonExploreMapWidget extends ConsumerStatefulWidget {
  const SalonExploreMapWidget({
    this.controlsTopInset = AppSpacing.sm,
    super.key,
  });

  final double controlsTopInset;

  @override
  ConsumerState<SalonExploreMapWidget> createState() =>
      _SalonExploreMapWidgetState();
}

class _SalonExploreMapWidgetState extends ConsumerState<SalonExploreMapWidget> {
  static const _guatemalaCity = GeoCoordinates(
    latitude: 14.6349,
    longitude: -90.5069,
  );
  static const _defaultRadiusKm = 10.0;
  static const _defaultZoom = 15.0;
  static const _cameraSearchDelay = Duration(milliseconds: 800);
  static const _markerPulsePeriod = Duration(milliseconds: 360);
  static const _markerPulseDuration = Duration(seconds: 3);

  SalonSearchArea _area = const SalonSearchArea(
    center: _guatemalaCity,
    radiusKm: _defaultRadiusKm,
  );
  List<NearbySalon> _displayedNearby = const [];
  GoogleMapController? _mapController;
  GeoCoordinates _cameraCenter = _guatemalaCity;
  String? _focusedSalonId;
  bool _locating = false;
  bool _showUserLocation = false;
  bool _hasPendingCameraSearch = false;
  bool _locationPromptShownThisVisit = false;
  bool _recheckLocationOnResume = false;
  BitmapDescriptor? _fallbackMarkerIcon;
  final Map<String, BitmapDescriptor> _salonMarkerIcons = {};
  final Map<String, String> _markerSignatures = {};
  int? _markerColorValue;
  AppLifecycleListener? _lifecycleListener;
  Timer? _cameraSearchDebounce;
  Timer? _markerPulseTimer;
  Timer? _markerPulseStopTimer;
  final Stopwatch _searchAge = Stopwatch()..start();
  String? _pulsingSalonId;
  BitmapDescriptor? _pulsingMarkerIcon;
  bool _markerPulseExpanded = false;
  int _markerPulseGeneration = 0;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onResume: _onAppResumed);
    final storedLocation = ref.read(lastExploreLocationProvider);
    if (storedLocation != null) {
      _cameraCenter = storedLocation;
      _area = SalonSearchArea(center: storedLocation, radiusKm: _area.radiusKm);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_ensureLocationOnEntry());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final accentColor = Theme.of(context).colorScheme.primary;
    final colorValue = accentColor.toARGB32();
    if (_markerColorValue == colorValue) return;
    _markerColorValue = colorValue;
    _fallbackMarkerIcon = null;
    _salonMarkerIcons.clear();
    _markerSignatures.clear();
    unawaited(_prepareFallbackMarker(accentColor));
  }

  @override
  void dispose() {
    _cameraSearchDebounce?.cancel();
    _markerPulseTimer?.cancel();
    _markerPulseStopTimer?.cancel();
    _lifecycleListener?.dispose();
    _mapController?.dispose();
    super.dispose();
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
          'Jolom usa tu ubicación para mostrarte las peluquerías cercanas. '
          'Puedes cambiar este permiso cuando quieras desde Ajustes.',
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

  Future<void> _useCurrentLocation() async {
    _cameraSearchDebounce?.cancel();
    _cancelMarkerPulse();
    setState(() => _locating = true);
    try {
      final coordinates =
          await DeviceLocationController.getCurrentCoordinates();
      if (!mounted) return;
      unawaited(_saveLastLocation(coordinates));
      final shouldRefreshSearch = _shouldRefreshSearchAt(coordinates);
      setState(() {
        _showUserLocation = true;
        _cameraCenter = coordinates;
        if (shouldRefreshSearch) {
          _area = SalonSearchArea(
            center: coordinates,
            radiusKm: _area.radiusKm,
          );
          _searchAge.reset();
        }
        _hasPendingCameraSearch = false;
      });
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(coordinates.latitude, coordinates.longitude),
          _defaultZoom,
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

  Future<void> _saveLastLocation(GeoCoordinates coordinates) async {
    try {
      await ref.read(lastExploreLocationProvider.notifier).save(coordinates);
    } catch (_) {
      // La persistencia local no debe impedir que el mapa use el GPS actual.
    }
  }

  void _scheduleCameraSearch() {
    _cameraSearchDebounce?.cancel();
    if (!_hasPendingCameraSearch) return;
    _cameraSearchDebounce = Timer(
      _cameraSearchDelay,
      _applyPendingCameraSearch,
    );
  }

  void _applyPendingCameraSearch() {
    _cameraSearchDebounce = null;
    if (!mounted || !_hasPendingCameraSearch) return;
    if (!_shouldRefreshSearchAt(_cameraCenter)) {
      _hasPendingCameraSearch = false;
      return;
    }
    _cancelMarkerPulse();
    setState(() {
      _area = SalonSearchArea(center: _cameraCenter, radiusKm: _area.radiusKm);
      _searchAge.reset();
      _hasPendingCameraSearch = false;
    });
  }

  void _retainNearbyResult(
    SalonSearchArea requestedArea,
    List<NearbySalon> items,
  ) {
    if (!mounted || requestedArea != _area) return;
    final focusedSalonRemains =
        _focusedSalonId != null &&
        items.any((item) => item.salon.id == _focusedSalonId);
    final pulsingId = _pulsingSalonId;
    final keepsPulsingSalon =
        pulsingId != null && items.any((item) => item.salon.id == pulsingId);

    setState(() {
      _displayedNearby = List.unmodifiable(items);
      if (!focusedSalonRemains) _focusedSalonId = null;
      if (!keepsPulsingSalon) _cancelMarkerPulse();
    });
  }

  Future<void> _prepareFallbackMarker(Color accentColor) async {
    try {
      final icon = await SalonMapMarkerController.create(
        accentColor: accentColor,
      );
      if (!mounted || _markerColorValue != accentColor.toARGB32()) return;
      setState(() => _fallbackMarkerIcon = icon);
    } catch (_) {
      // El mapa puede seguir funcionando aunque falle la creación del ícono.
    }
  }

  void _prepareSalonMarkers(List<NearbySalon> salons, Color accentColor) {
    for (final item in salons) {
      final salon = item.salon;
      final imageUrl = salonPrimaryImageUrl(salon);
      final signature = '${accentColor.toARGB32()}:${imageUrl ?? ''}';
      if (_markerSignatures[salon.id] == signature) continue;
      _markerSignatures[salon.id] = signature;
      unawaited(
        _prepareSalonMarker(
          salonId: salon.id,
          signature: signature,
          imageUrl: imageUrl,
          accentColor: accentColor,
        ),
      );
    }
  }

  Future<void> _prepareSalonMarker({
    required String salonId,
    required String signature,
    required String? imageUrl,
    required Color accentColor,
  }) async {
    try {
      final icon = await SalonMapMarkerController.create(
        accentColor: accentColor,
        imageUrl: imageUrl,
      );
      if (!mounted || _markerSignatures[salonId] != signature) return;
      setState(() => _salonMarkerIcons[salonId] = icon);
    } catch (_) {
      // Mantener el marcador de respaldo personalizado.
    }
  }

  Future<void> _startMarkerPulse(NearbySalon item, Color accentColor) async {
    setState(_cancelMarkerPulse);
    final generation = _markerPulseGeneration;
    final imageUrl = salonPrimaryImageUrl(item.salon);

    try {
      final pulseIcon = await SalonMapMarkerController.create(
        accentColor: accentColor,
        imageUrl: imageUrl,
        displayScale: 1.32,
      );
      if (!mounted || generation != _markerPulseGeneration) return;

      setState(() {
        _pulsingSalonId = item.salon.id;
        _pulsingMarkerIcon = pulseIcon;
        _markerPulseExpanded = true;
      });
      _markerPulseTimer = Timer.periodic(_markerPulsePeriod, (timer) {
        if (!mounted || generation != _markerPulseGeneration) {
          timer.cancel();
          return;
        }
        setState(() => _markerPulseExpanded = !_markerPulseExpanded);
      });
      _markerPulseStopTimer = Timer(_markerPulseDuration, () {
        if (!mounted || generation != _markerPulseGeneration) return;
        setState(_cancelMarkerPulse);
      });
    } catch (_) {
      // Si falla el ícono ampliado, el marcador normal permanece disponible.
    }
  }

  void _cancelMarkerPulse() {
    _markerPulseGeneration++;
    _markerPulseTimer?.cancel();
    _markerPulseStopTimer?.cancel();
    _markerPulseTimer = null;
    _markerPulseStopTimer = null;
    _pulsingSalonId = null;
    _pulsingMarkerIcon = null;
    _markerPulseExpanded = false;
  }

  void _selectSalon(NearbySalon item) {
    setState(() {
      _cancelMarkerPulse();
      _focusedSalonId = item.salon.id;
    });
  }

  void _clearFocusedSalon() {
    setState(() {
      _cancelMarkerPulse();
      _focusedSalonId = null;
    });
  }

  void _openSalon(String salonId) {
    setState(_cancelMarkerPulse);
    context.push('/salon/$salonId');
  }

  void _trackCamera(CameraPosition position) {
    _cameraSearchDebounce?.cancel();
    _cameraCenter = GeoCoordinates(
      latitude: position.target.latitude,
      longitude: position.target.longitude,
    );
    _hasPendingCameraSearch = _shouldRefreshSearchAt(_cameraCenter);
  }

  bool _shouldRefreshSearchAt(GeoCoordinates center) =>
      SalonExploreSearchPolicy.shouldRefresh(
        lastQueryCenter: _area.center,
        candidateCenter: center,
        timeSinceLastQuery: _searchAge.elapsed,
      );

  void _handleMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (!_showUserLocation) return;
    unawaited(
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_area.center.latitude, _area.center.longitude),
          _defaultZoom,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requestedArea = _area;
    final provider = nearbySalonsProvider(requestedArea);
    ref.listen<AsyncValue<List<NearbySalon>>>(provider, (previous, next) {
      final items = next.value;
      if (next.hasValue && items != null) {
        _retainNearbyResult(requestedArea, items);
      }
    });
    final nearbyAsync = ref.watch(provider);
    final nearby = nearbyAsync.value ?? _displayedNearby;
    NearbySalon? selectedSalon;
    if (_focusedSalonId != null) {
      for (final item in nearby) {
        if (item.salon.id == _focusedSalonId) {
          selectedSalon = item;
          break;
        }
      }
    }
    final scheme = Theme.of(context).colorScheme;
    final bottomOverlayInset = appBottomOverlayInset(context);
    _prepareSalonMarkers(nearby, scheme.primary);
    final markers = nearby
        .where(
          (item) =>
              _salonMarkerIcons[item.salon.id] != null ||
              _fallbackMarkerIcon != null,
        )
        .map((item) {
          final pulsing = _pulsingSalonId == item.salon.id;
          final useExpandedIcon =
              pulsing && _markerPulseExpanded && _pulsingMarkerIcon != null;
          return Marker(
            markerId: MarkerId(item.salon.id),
            position: LatLng(item.salon.latitude!, item.salon.longitude!),
            icon: useExpandedIcon
                ? _pulsingMarkerIcon!
                : _salonMarkerIcons[item.salon.id] ?? _fallbackMarkerIcon!,
            anchor: const Offset(0.5, 0.96),
            consumeTapEvents: true,
            zIndexInt: pulsing
                ? 3
                : _focusedSalonId == item.salon.id
                ? 2
                : 1,
            onTap: () => _selectSalon(item),
          );
        })
        .toSet();

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(_area.center.latitude, _area.center.longitude),
            zoom: _defaultZoom,
          ),
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          myLocationEnabled: _showUserLocation,
          zoomControlsEnabled: false,
          markers: markers,
          circles: {
            Circle(
              circleId: const CircleId('search-area'),
              center: LatLng(_area.center.latitude, _area.center.longitude),
              radius: _area.radiusKm * 1000,
              fillColor: scheme.primary.withValues(alpha: 0.07),
              strokeColor: scheme.primary.withValues(alpha: 0.35),
              strokeWidth: 2,
            ),
          },
          onMapCreated: _handleMapCreated,
          onCameraMove: _trackCamera,
          onCameraIdle: _scheduleCameraSearch,
          onTap: (_) => _clearFocusedSalon(),
        ),
        Positioned(
          top: widget.controlsTopInset,
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          child: SalonMapControlsWidget(
            locating: _locating,
            onUseCurrentLocation: _useCurrentLocation,
          ),
        ),
        if (nearbyAsync.isLoading && nearby.isEmpty)
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        if (nearbyAsync.hasError && nearby.isEmpty)
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: bottomOverlayInset,
            child: SalonMapMessageWidget(
              icon: Icons.error_outline,
              message: userFacingError(
                nearbyAsync.error!,
                nearbyAsync.stackTrace,
              ),
            ),
          )
        else if (nearbyAsync.hasValue && nearby.isEmpty)
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: bottomOverlayInset,
            child: const SalonMapMessageWidget(
              icon: Icons.content_cut,
              message: 'No hay peluquerías con ubicación dentro de este radio.',
            ),
          )
        else if (nearby.isNotEmpty)
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: bottomOverlayInset,
            child: SalonMapBusinessCarouselWidget(
              key: const ValueKey('nearby-salons'),
              items: nearby,
              onHighlight: (item) => _startMarkerPulse(item, scheme.primary),
              onOpen: (item) => _openSalon(item.salon.id),
            ),
          ),
        Positioned(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: bottomOverlayInset + 104 + AppSpacing.xs,
          child: AnimatedSwitcher(
            duration: AppMotion.durationOf(context, AppMotion.normal),
            switchInCurve: AppMotion.curveOf(context, AppMotion.decelerate),
            switchOutCurve: AppMotion.curveOf(context, AppMotion.standard),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.08),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: selectedSalon == null
                ? const SizedBox.shrink(
                    key: ValueKey('no-selected-map-business'),
                  )
                : SalonMapSelectedBusinessPreviewWidget(
                    key: ValueKey(
                      'selected-map-business-${selectedSalon.salon.id}',
                    ),
                    item: selectedSalon,
                    onClose: _clearFocusedSalon,
                    onOpen: () => _openSalon(selectedSalon!.salon.id),
                  ),
          ),
        ),
      ],
    );
  }
}
