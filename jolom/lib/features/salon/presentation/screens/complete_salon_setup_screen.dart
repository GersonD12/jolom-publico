import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';
import 'package:jolom/features/salon/domain/entities/nearby_salon_entity.dart';
import 'package:jolom/features/salon/domain/entities/salon_entity.dart';
import 'package:jolom/features/salon/domain/repositories/salon_repository.dart';
import 'package:jolom/features/salon/infrastructure/place_image_storage_service.dart';
import 'package:jolom/features/salon/presentation/widgets/place_gallery_editor_widget.dart';
import 'package:jolom/features/salon/presentation/widgets/salon_onboarding_header_widget.dart';
import 'package:jolom/shared/widgets/pill_button_widget.dart';
import 'package:jolom/shared/widgets/soft_card_widget.dart';

import '../controllers/device_location_controller.dart';
import 'salon_location_picker_screen.dart';

/// Último paso del alta inicial: fotos y ubicación del negocio.
class CompleteSalonSetupScreen extends ConsumerStatefulWidget {
  const CompleteSalonSetupScreen({required this.salonId, super.key});

  final String salonId;

  @override
  ConsumerState<CompleteSalonSetupScreen> createState() =>
      _CompleteSalonSetupScreenState();
}

class _CompleteSalonSetupScreenState
    extends ConsumerState<CompleteSalonSetupScreen> {
  final _photosSectionKey = GlobalKey();
  final _locationSectionKey = GlobalKey();
  Salon? _salon;
  List<EditablePlaceImage> _placeImages = [];
  bool _galleryDirty = false;
  bool _locationDirty = false;
  bool _loading = true;
  bool _saving = false;
  bool _capturingLocation = false;
  bool _showImageError = false;
  bool _showLocationError = false;
  double? _latitude;
  double? _longitude;

  late final UnsavedChangesNotifier _unsavedChangesNotifier;

  bool get _hasLocation => _latitude != null && _longitude != null;

  bool get _hasUnsavedChanges => _galleryDirty || _locationDirty;

  @override
  void initState() {
    super.initState();
    _unsavedChangesNotifier = ref.read(
      completeSalonSetupUnsavedChangesProvider.notifier,
    );
    _load();
  }

  void _syncUnsavedChangesProvider() {
    _unsavedChangesNotifier.setDirty(_hasUnsavedChanges);
  }

  Future<void> _load() async {
    final salonId = widget.salonId.trim();
    if (salonId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final salon = await getIt<SalonRepository>().getSalon(salonId);
    if (!mounted) return;
    setState(() {
      _salon = salon;
      if (salon != null) {
        _placeImages = salon.imageUrls.map(EditablePlaceImage.remote).toList();
        _latitude = salon.latitude;
        _longitude = salon.longitude;
      }
      _loading = false;
    });
    _syncUnsavedChangesProvider();
  }

  Future<void> _captureGpsLocation() async {
    setState(() => _capturingLocation = true);
    try {
      final coordinates =
          await DeviceLocationController.getCurrentCoordinates();
      if (!mounted) return;
      setState(() {
        _latitude = coordinates.latitude;
        _longitude = coordinates.longitude;
        _locationDirty = true;
        _showLocationError = false;
      });
      _syncUnsavedChangesProvider();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    } finally {
      if (mounted) setState(() => _capturingLocation = false);
    }
  }

  Future<void> _pickLocationOnMap() async {
    final selected = await Navigator.of(context).push<GeoCoordinates>(
      MaterialPageRoute(
        builder: (_) => SalonLocationPickerScreen(
          initialCoordinates: _hasLocation
              ? GeoCoordinates(latitude: _latitude!, longitude: _longitude!)
              : null,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _latitude = selected.latitude;
      _longitude = selected.longitude;
      _locationDirty = true;
      _showLocationError = false;
    });
    _syncUnsavedChangesProvider();
  }

  Future<void> _completeSetup() async {
    final salon = _salon;
    if (salon == null || _saving) return;

    final hasImage = _placeImages.isNotEmpty;
    if (!hasImage || !_hasLocation) {
      setState(() {
        _showImageError = !hasImage;
        _showLocationError = !_hasLocation;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targetContext = hasImage
            ? _locationSectionKey.currentContext
            : _photosSectionKey.currentContext;
        if (targetContext == null) return;
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.08,
          duration: AppMotion.durationOf(context, AppMotion.normal),
          curve: AppMotion.curveOf(context, AppMotion.decelerate),
        );
      });
      return;
    }

    setState(() => _saving = true);
    try {
      String? coverImageUrl;
      List<String>? imageUrls;

      if (_galleryDirty) {
        final sync = await getIt<PlaceImageStorageService>().syncPlaceImages(
          salonId: salon.id,
          entries: _placeImages.map((image) => image.toEntry()).toList(),
          previousFirstImageUrl: salon.imageUrls.isNotEmpty
              ? salon.imageUrls.first
              : null,
          previousCoverImageUrl: salon.coverImageUrl,
        );
        imageUrls = sync.imageUrls;
        coverImageUrl = sync.coverImageUrl;
      }

      await getIt<SalonRepository>().updateSalon(
        salonId: salon.id,
        latitude: _locationDirty ? _latitude : null,
        longitude: _locationDirty ? _longitude : null,
        imageUrls: imageUrls,
        coverImageUrl: _galleryDirty ? (coverImageUrl ?? '') : null,
      );
      if (!mounted) return;
      setState(() {
        _galleryDirty = false;
        _locationDirty = false;
      });
      _syncUnsavedChangesProvider();
      context.go(
        Uri(
          path: '/onboarding/salon/service',
          queryParameters: {'salonId': salon.id},
        ).toString(),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final salon = _salon;
    if (salon == null) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: Text('No se encontró la peluquería.')),
        ),
      );
    }

    final canContinue = _placeImages.isNotEmpty && _hasLocation;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Configura tu negocio'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: 1 / 3,
            minHeight: 4,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
      body: ListView(
        padding: appScrollPadding(
          context,
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
          bottom: 112,
        ),
        children: [
          SalonOnboardingHeaderWidget(
            step: 1,
            title: 'Dale vida a ${salon.name}',
            description:
                'Agrega una buena foto y confirma la ubicación para que tus '
                'clientes puedan encontrarte.',
          ),
          const SizedBox(height: AppSpacing.lg),
          SoftCardWidget(
            key: _photosSectionKey,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  number: '1',
                  title: 'Muestra tu negocio',
                  completed: _placeImages.isNotEmpty,
                ),
                const SizedBox(height: AppSpacing.md),
                PlaceGalleryEditorWidget(
                  images: _placeImages,
                  onChanged: (next) {
                    setState(() {
                      _placeImages = next;
                      _galleryDirty = true;
                      if (next.isNotEmpty) _showImageError = false;
                    });
                    _syncUnsavedChangesProvider();
                  },
                ),
                if (_showImageError) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Agrega al menos una foto para continuar.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SoftCardWidget(
            key: _locationSectionKey,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  number: '2',
                  title: 'Confirma dónde estás',
                  completed: _hasLocation,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'El punto exacto ayuda a que tus clientes te encuentren en '
                  'el mapa y en búsquedas cercanas.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: _hasLocation
                        ? theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.45,
                          )
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _hasLocation
                            ? Icons.location_on_rounded
                            : Icons.location_off_outlined,
                        color: _hasLocation
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _hasLocation
                              ? 'Ubicación confirmada'
                              : 'Ubicación pendiente',
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showLocationError) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Selecciona un punto en el mapa para continuar.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickLocationOnMap,
                  icon: const Icon(Icons.map_outlined),
                  label: Text(
                    _hasLocation
                        ? 'Ajustar punto en el mapa'
                        : 'Elegir en el mapa',
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton.icon(
                  onPressed: _saving || _capturingLocation
                      ? null
                      : _captureGpsLocation,
                  icon: _capturingLocation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                  label: Text(
                    _capturingLocation
                        ? 'Obteniendo ubicación…'
                        : 'Usar mi ubicación actual',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: PillButtonWidget(
          label: 'Continuar al servicio',
          icon: Icons.arrow_forward_rounded,
          loading: _saving,
          onPressed: canContinue ? _completeSetup : null,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.number,
    required this.title,
    required this.completed,
  });

  final String number;
  final String title;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: completed
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          foregroundColor: completed
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant,
          child: completed
              ? const Icon(Icons.check_rounded, size: 18)
              : Text(number, style: theme.textTheme.labelMedium),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
