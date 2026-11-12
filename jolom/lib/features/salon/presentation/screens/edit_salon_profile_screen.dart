import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';
import 'package:jolom/features/salon/domain/entities/salon_entity.dart';
import 'package:jolom/features/salon/domain/entities/nearby_salon_entity.dart';
import 'package:jolom/features/salon/domain/repositories/salon_repository.dart';
import 'package:jolom/features/salon/domain/validation/salon_input_limits.dart';
import 'package:jolom/features/salon/infrastructure/place_image_storage_service.dart';
import 'package:jolom/features/salon/presentation/widgets/place_gallery_editor_widget.dart';
import 'package:jolom/shared/widgets/pulsing_save_button_widget.dart';

import '../controllers/device_location_controller.dart';
import 'salon_location_picker_screen.dart';

/// Edición de la ficha principal del salón (nombre, descripción, contacto, fotos).
class EditSalonProfileScreen extends ConsumerStatefulWidget {
  const EditSalonProfileScreen({this.salonId, super.key});

  /// Permite cargar la peluquería recién creada mientras hidrata la membresía.
  final String? salonId;

  @override
  ConsumerState<EditSalonProfileScreen> createState() =>
      _EditSalonProfileScreenState();
}

class _EditSalonProfileScreenState
    extends ConsumerState<EditSalonProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  Salon? _salon;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  List<EditablePlaceImage> _placeImages = [];
  bool _galleryDirty = false;
  bool _loading = true;
  bool _saving = false;
  bool _capturingLocation = false;
  bool _showImageError = false;
  bool _showLocationError = false;

  /// Coords capturadas (o ya guardadas) pendientes de enviar en Guardar.
  double? _latitude;
  double? _longitude;
  bool _locationDirty = false;

  String _savedName = '';
  String _savedDesc = '';
  String _savedPhone = '';
  String _savedAddress = '';

  late final UnsavedChangesNotifier _unsavedChangesNotifier;
  bool _suppressTextListener = false;

  @override
  void initState() {
    super.initState();
    _unsavedChangesNotifier = ref.read(
      editSalonUnsavedChangesProvider.notifier,
    );
    _nameCtrl.addListener(_onTextFieldsChanged);
    _descCtrl.addListener(_onTextFieldsChanged);
    _phoneCtrl.addListener(_onTextFieldsChanged);
    _addressCtrl.addListener(_onTextFieldsChanged);
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onTextFieldsChanged);
    _descCtrl.removeListener(_onTextFieldsChanged);
    _phoneCtrl.removeListener(_onTextFieldsChanged);
    _addressCtrl.removeListener(_onTextFieldsChanged);
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  String get _locationStatusLabel {
    final lat = _latitude;
    final lng = _longitude;
    if (lat == null || lng == null) return 'Sin ubicación GPS';
    return 'Ubicación lista (${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
  }

  bool get _textDirty =>
      _nameCtrl.text != _savedName ||
      _descCtrl.text != _savedDesc ||
      _phoneCtrl.text != _savedPhone ||
      _addressCtrl.text != _savedAddress;

  bool get _hasUnsavedChanges => _textDirty || _galleryDirty || _locationDirty;

  void _syncUnsavedChangesProvider() {
    _unsavedChangesNotifier.setDirty(_hasUnsavedChanges);
  }

  void _onTextFieldsChanged() {
    if (_suppressTextListener) return;
    _syncUnsavedChangesProvider();
    if (mounted) setState(() {});
  }

  void _captureSavedTexts() {
    _savedName = _nameCtrl.text;
    _savedDesc = _descCtrl.text;
    _savedPhone = _phoneCtrl.text;
    _savedAddress = _addressCtrl.text;
  }

  void _clearDirtyAfterSave() {
    setState(() {
      _galleryDirty = false;
      _locationDirty = false;
      _captureSavedTexts();
    });
    _syncUnsavedChangesProvider();
  }

  Future<void> _load() async {
    final membership = ref.read(membershipProvider).value;
    final salonId = widget.salonId ?? membership?.salonId;
    if (salonId == null) {
      setState(() => _loading = false);
      return;
    }
    final salon = await getIt<SalonRepository>().getSalon(salonId);
    if (!mounted) return;
    _suppressTextListener = true;
    setState(() {
      _salon = salon;
      if (salon != null) {
        _nameCtrl.text = salon.name;
        _descCtrl.text = salon.description ?? '';
        _phoneCtrl.text = salon.contactPhone ?? '';
        _addressCtrl.text = salon.address ?? '';
        _placeImages = salon.imageUrls.map(EditablePlaceImage.remote).toList();
        _galleryDirty = false;
        _latitude = salon.latitude;
        _longitude = salon.longitude;
        _locationDirty = false;
        _showImageError = false;
        _showLocationError = false;
        _captureSavedTexts();
      }
      _loading = false;
    });
    _suppressTextListener = false;
    _syncUnsavedChangesProvider();
  }

  /// Pide permiso y usa la posición actual como ubicación del negocio.
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ubicación GPS capturada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _capturingLocation = false);
    }
  }

  Future<void> _pickLocationOnMap() async {
    final latitude = _latitude;
    final longitude = _longitude;
    final selected = await Navigator.of(context).push<GeoCoordinates>(
      MaterialPageRoute(
        builder: (_) => SalonLocationPickerScreen(
          initialCoordinates: latitude != null && longitude != null
              ? GeoCoordinates(latitude: latitude, longitude: longitude)
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

  Future<void> _save() async {
    final salon = _salon;
    if (salon == null) return;
    final formIsValid = _formKey.currentState!.validate();
    final hasImage = _placeImages.isNotEmpty;
    final hasLocation = _latitude != null && _longitude != null;
    if (!hasImage) {
      setState(() => _showImageError = true);
    }
    if (!hasLocation) {
      setState(() => _showLocationError = true);
    }
    if (!formIsValid || !hasImage || !hasLocation) return;
    setState(() => _saving = true);
    try {
      String? coverImageUrl;
      List<String>? imageUrls;

      if (_galleryDirty) {
        final sync = await getIt<PlaceImageStorageService>().syncPlaceImages(
          salonId: salon.id,
          entries: _placeImages.map((e) => e.toEntry()).toList(),
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
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        contactPhone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        latitude: _locationDirty ? _latitude : null,
        longitude: _locationDirty ? _longitude : null,
        imageUrls: imageUrls,
        // Fallback defensivo: evita conservar una portada inconsistente.
        coverImageUrl: _galleryDirty ? (coverImageUrl ?? '') : null,
      );
      if (!mounted) return;
      _clearDirtyAfterSave();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ficha actualizada.')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar perfil')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_salon == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar perfil')),
        body: const Center(child: Text('No se encontró la peluquería.')),
      );
    }

    final theme = Theme.of(context);
    final hasCoords = _latitude != null && _longitude != null;
    final hasUnsavedChanges = _hasUnsavedChanges;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: appScrollPadding(context, horizontal: 16, vertical: 16),
          children: [
            PlaceGalleryEditorWidget(
              images: _placeImages,
              onChanged: (next) {
                setState(() {
                  _placeImages = next;
                  _galleryDirty = true;
                  _showImageError = next.isEmpty;
                });
                _syncUnsavedChangesProvider();
              },
            ),
            if (_showImageError) ...[
              const SizedBox(height: 4),
              Text(
                'Conserva al menos una foto del negocio.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameCtrl,
              maxLength: SalonInputLimits.salonNameMaxLength,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) return 'Ingresa un nombre';
                if (!SalonInputLimits.isTextWithinLimit(
                  name,
                  SalonInputLimits.salonNameMaxLength,
                )) {
                  return 'Máximo ${SalonInputLimits.salonNameMaxLength} caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLength: SalonInputLimits.salonDescriptionMaxLength,
              decoration: AppInputDecoration.multiline(
                context,
                labelText: 'Descripción',
              ),
              minLines: 3,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              validator: (value) =>
                  SalonInputLimits.isTextWithinLimit(
                    value?.trim() ?? '',
                    SalonInputLimits.salonDescriptionMaxLength,
                  )
                  ? null
                  : 'Máximo ${SalonInputLimits.salonDescriptionMaxLength} caracteres',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              maxLength: SalonInputLimits.salonPhoneMaxLength,
              decoration: const InputDecoration(labelText: 'Teléfono'),
              keyboardType: TextInputType.phone,
              validator: (value) =>
                  SalonInputLimits.isTextWithinLimit(
                    value?.trim() ?? '',
                    SalonInputLimits.salonPhoneMaxLength,
                  )
                  ? null
                  : 'Máximo ${SalonInputLimits.salonPhoneMaxLength} caracteres',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressCtrl,
              maxLength: SalonInputLimits.salonAddressMaxLength,
              decoration: const InputDecoration(labelText: 'Dirección'),
              validator: (value) =>
                  SalonInputLimits.isTextWithinLimit(
                    value?.trim() ?? '',
                    SalonInputLimits.salonAddressMaxLength,
                  )
                  ? null
                  : 'Máximo ${SalonInputLimits.salonAddressMaxLength} caracteres',
            ),
            const SizedBox(height: 12),
            Text('Punto en el mapa', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Agrega el punto exacto de tu negocio. Es obligatorio para que '
              'las personas '
              'puedan encontrarlo en el mapa y en las búsquedas cercanas.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _locationStatusLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: hasCoords
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_showLocationError) ...[
              const SizedBox(height: 4),
              Text(
                'Selecciona un punto en el mapa para continuar.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickLocationOnMap,
              icon: const Icon(Icons.map_outlined),
              label: Text(
                hasCoords ? 'Ajustar punto en el mapa' : 'Elegir en el mapa',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: (_saving || _capturingLocation)
                  ? null
                  : _captureGpsLocation,
              icon: _capturingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(
                _capturingLocation
                    ? 'Obteniendo ubicación…'
                    : 'Usar mi ubicación GPS',
              ),
            ),
            const SizedBox(height: 24),
            PulsingSaveButtonWidget(
              label: 'Guardar',
              loading: _saving,
              pulse: hasUnsavedChanges,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
