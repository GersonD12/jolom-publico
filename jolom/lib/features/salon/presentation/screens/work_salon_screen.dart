import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';
import 'package:jolom/features/salon/domain/entities/salon_entity.dart';
import 'package:jolom/features/salon/domain/entities/service_entity.dart';
import 'package:jolom/features/salon/domain/repositories/salon_repository.dart';
import 'package:jolom/features/salon/domain/validation/salon_input_limits.dart';
import 'package:jolom/features/salon/presentation/utils/service_form_utils.dart';
import 'package:jolom/features/salon/presentation/widgets/place_gallery_preview_widget.dart';
import 'package:jolom/features/salon/presentation/widgets/salon_share_sheet.dart';
import 'package:jolom/shared/widgets/app_modal_bottom_sheet.dart';
import 'package:jolom/shared/widgets/pill_button_widget.dart';

/// Gestión de ficha, servicios y publicación (propietario).
class WorkSalonScreen extends ConsumerStatefulWidget {
  const WorkSalonScreen({super.key});

  @override
  ConsumerState<WorkSalonScreen> createState() => _WorkSalonScreenState();
}

class _WorkSalonScreenState extends ConsumerState<WorkSalonScreen> {
  final _createServiceFormKey = GlobalKey<FormState>();
  Salon? _salon;
  List<Service> _services = [];
  final _serviceNameCtrl = TextEditingController();
  final _servicePriceCtrl = TextEditingController(text: '50');
  final _serviceDurationCtrl = TextEditingController(text: '30');
  bool _loading = true;
  SalonPublishStatus? _publishInFlight;
  bool _addingService = false;
  final Set<String> _serviceUpdatesInFlight = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _serviceNameCtrl.dispose();
    _servicePriceCtrl.dispose();
    _serviceDurationCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final membership = ref.read(membershipProvider).value;
    if (membership == null) {
      setState(() => _loading = false);
      return;
    }
    final salon = await getIt<SalonRepository>().getSalon(membership.salonId);
    final services = await getIt<SalonRepository>().listServices(
      membership.salonId,
      includeInactive: true,
    );
    if (!mounted) return;
    setState(() {
      _salon = salon;
      _services = services;
      _loading = false;
    });
  }

  Future<void> _openEditProfile() async {
    await context.push('/work/salon/edit');
    if (mounted) await _load();
  }

  void _openSalonShareSheet() {
    final salon = _salon;
    if (salon == null) return;
    showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SalonShareSheet(salonId: salon.id),
    );
  }

  Future<void> _publish(SalonPublishStatus status) async {
    final salon = _salon;
    if (salon == null || _publishInFlight != null) return;
    final idempotencyKey =
        'setSalonPublishStatus_${salon.id}_${status.name}_${DateTime.now().microsecondsSinceEpoch}';
    setState(() => _publishInFlight = status);
    try {
      await getIt<SalonRepository>().setSalonPublishStatus(
        salonId: salon.id,
        publishStatus: status,
        idempotencyKey: idempotencyKey,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) {
        setState(() => _publishInFlight = null);
      }
    }
  }

  Future<void> _addService() async {
    FocusScope.of(context).unfocus();
    final salon = _salon;
    final name = _serviceNameCtrl.text.trim();
    if (salon == null ||
        _addingService ||
        !_createServiceFormKey.currentState!.validate()) {
      return;
    }
    final durationMinutes = int.parse(_serviceDurationCtrl.text.trim());
    final price = double.parse(
      _servicePriceCtrl.text.trim().replaceAll(',', '.'),
    );
    final idempotencyKey =
        'createService_${salon.id}_${DateTime.now().microsecondsSinceEpoch}';
    setState(() => _addingService = true);
    try {
      await getIt<SalonRepository>().createService(
        salonId: salon.id,
        name: name,
        durationMinutes: durationMinutes,
        price: price,
        idempotencyKey: idempotencyKey,
      );
      _serviceNameCtrl.clear();
      _createServiceFormKey.currentState?.reset();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) {
        setState(() => _addingService = false);
      }
    }
  }

  Future<void> _openCreateServiceSheet() async {
    final salon = _salon;
    if (salon == null) return;
    final created = await showAppModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CreateServiceBottomSheet(salonId: salon.id),
    );
    if (created == true && mounted) {
      await _load();
    }
  }

  Future<void> _toggleService(Service service) async {
    if (_serviceUpdatesInFlight.contains(service.id)) return;

    setState(() => _serviceUpdatesInFlight.add(service.id));
    try {
      await getIt<SalonRepository>().updateService(
        serviceId: service.id,
        status: service.isActive ? 'inactive' : 'active',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) {
        setState(() => _serviceUpdatesInFlight.remove(service.id));
      }
    }
  }

  Future<void> _editService(Service service) async {
    if (_serviceUpdatesInFlight.contains(service.id)) return;

    final draft = await showDialog<_ServiceDraft>(
      context: context,
      builder: (context) => _EditServiceDialog(service: service),
    );
    if (draft == null || !mounted) return;

    final idempotencyKey =
        'updateService_${service.id}_${DateTime.now().microsecondsSinceEpoch}';
    setState(() => _serviceUpdatesInFlight.add(service.id));
    try {
      await getIt<SalonRepository>().updateService(
        serviceId: service.id,
        name: draft.name,
        durationMinutes: draft.durationMinutes,
        price: draft.price,
        idempotencyKey: idempotencyKey,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) {
        setState(() => _serviceUpdatesInFlight.remove(service.id));
      }
    }
  }

  Future<void> _deleteService(Service service) async {
    if (_serviceUpdatesInFlight.contains(service.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar servicio'),
        content: Text(
          '¿Quieres eliminar “${service.name}”? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final idempotencyKey =
        'deleteService_${service.id}_${DateTime.now().microsecondsSinceEpoch}';
    setState(() => _serviceUpdatesInFlight.add(service.id));
    try {
      await getIt<SalonRepository>().updateService(
        serviceId: service.id,
        isDeleted: true,
        idempotencyKey: idempotencyKey,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) {
        setState(() => _serviceUpdatesInFlight.remove(service.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(membershipProvider).value;
    if (membership == null || !membership.isOwner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Negocio')),
        body: const Center(
          child: Text('Solo el propietario gestiona la peluquería.'),
        ),
      );
    }
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final salon = _salon;
    final hasActiveService = _services.any((s) => s.isActive);
    final description = salon?.description?.trim();
    final phone = salon?.contactPhone?.trim();
    final address = salon?.address?.trim();
    final isPublishing = _publishInFlight == SalonPublishStatus.published;
    final isHiding = _publishInFlight == SalonPublishStatus.hidden;
    final publishBusy = _publishInFlight != null;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mi peluquería'),
          actions: [
            // Fase 1: sin invitaciones de equipo.
            // IconButton(
            //   tooltip: 'Equipo',
            //   onPressed: () => context.push('/work/team'),
            //   icon: const Icon(Icons.groups_outlined),
            // ),
            IconButton(
              key: const ValueKey('salon-qr-button'),
              tooltip: 'QR',
              onPressed: _openSalonShareSheet,
              icon: const Icon(Icons.qr_code),
            ),
            IconButton(
              key: const ValueKey('salon-settings-button'),
              tooltip: 'Configuración del negocio',
              onPressed: () => context.push('/work/salon/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Perfil'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Servicios'),
                    if (_services.isEmpty) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Agrega tu primer servicio',
                        child: Icon(
                          Icons.error_rounded,
                          key: const ValueKey('missing-services-indicator'),
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: appScrollPadding(
                  context,
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                  bottom: appBottomActionClearance,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Estado: ${salon?.publishStatus.labelEs ?? '-'}',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('hide-salon-button'),
                        tooltip: isHiding
                            ? 'Ocultando peluquería'
                            : 'Ocultar peluquería',
                        onPressed: publishBusy
                            ? null
                            : () => _publish(SalonPublishStatus.hidden),
                        icon: isHiding
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.visibility_off),
                      ),
                    ],
                  ),
                  if (!hasActiveService) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Agrega al menos un servicio activo para poder publicar.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  if (salon != null &&
                      (salon.imageUrls.isNotEmpty ||
                          (salon.coverImageUrl != null &&
                              salon.coverImageUrl!.isNotEmpty))) ...[
                    const SizedBox(height: 16),
                    PlaceGalleryPreviewWidget(
                      imageUrls: salon.imageUrls,
                      coverImageUrl: salon.coverImageUrl,
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      'Fotos: 0',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    salon?.name.isNotEmpty == true ? salon!.name : 'Sin nombre',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description != null && description.isNotEmpty
                        ? description
                        : 'Sin descripción',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: description != null && description.isNotEmpty
                          ? null
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ProfileInfoRow(
                    icon: Icons.phone_outlined,
                    value: phone != null && phone.isNotEmpty
                        ? phone
                        : 'Sin teléfono',
                    muted: phone == null || phone.isEmpty,
                  ),
                  const SizedBox(height: 8),
                  _ProfileInfoRow(
                    icon: Icons.place_outlined,
                    value: address != null && address.isNotEmpty
                        ? address
                        : 'Sin dirección',
                    muted: address == null || address.isEmpty,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: _openEditProfile,
                            child: const Text('Editar perfil'),
                          ),
                        ),
                      ),
                      if (salon?.publishStatus !=
                          SalonPublishStatus.published) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: PillButtonWidget(
                            label: 'Publicar',
                            loading: isPublishing,
                            onPressed: hasActiveService && !publishBusy
                                ? () => _publish(SalonPublishStatus.published)
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: appScrollPadding(
                  context,
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                  bottom: appBottomActionClearance,
                ),
                children: [
                  if (_services.isEmpty) ...[
                    Container(
                      key: const ValueKey('empty-services-notice'),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: AppRadius.cardCompact,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.content_cut_rounded,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Aún no tienes servicios',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Agrega tu primer servicio para que los '
                                  'clientes puedan reservar y puedas publicar '
                                  'la peluquería.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tus servicios',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        IconButton.filled(
                          key: const ValueKey('add-service-button'),
                          tooltip: 'Agregar servicio',
                          onPressed: _openCreateServiceSheet,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  ..._services.map((s) {
                    final isUpdating = _serviceUpdatesInFlight.contains(s.id);
                    return ListTile(
                      title: Text(s.name),
                      subtitle: Text(
                        '${s.durationMinutes} min · ${s.price} ${s.currency} · ${s.statusLabelEs}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: isUpdating
                                ? 'Actualizando servicio'
                                : s.isActive
                                ? 'Ocultar servicio'
                                : 'Mostrar servicio',
                            onPressed: isUpdating
                                ? null
                                : () => _toggleService(s),
                            icon: isUpdating
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    s.isActive
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                          ),
                          PopupMenuButton<_ServiceAction>(
                            tooltip: 'Más acciones',
                            enabled: !isUpdating,
                            onSelected: (action) {
                              switch (action) {
                                case _ServiceAction.edit:
                                  _editService(s);
                                case _ServiceAction.delete:
                                  _deleteService(s);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: _ServiceAction.edit,
                                child: ListTile(
                                  leading: Icon(Icons.edit_outlined),
                                  title: Text('Editar'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              PopupMenuItem(
                                value: _ServiceAction.delete,
                                child: ListTile(
                                  leading: Icon(Icons.delete_outline),
                                  title: Text('Eliminar'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_services.isEmpty) ...[
                    Form(
                      key: _createServiceFormKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _serviceNameCtrl,
                            maxLength: SalonInputLimits.serviceNameMaxLength,
                            decoration: const InputDecoration(
                              labelText: 'Nuevo servicio',
                            ),
                            validator: validateServiceName,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _serviceDurationCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Minutos',
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                  validator: validateServiceDuration,
                                  onTapOutside: (_) =>
                                      FocusScope.of(context).unfocus(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _servicePriceCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Precio',
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: servicePriceInputFormatters,
                                  validator: validateServicePrice,
                                  onTapOutside: (_) =>
                                      FocusScope.of(context).unfocus(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _addingService ? null : _addService,
                      child: _addingService
                          ? const _InlineProgressLabel(label: 'Agregando')
                          : const Text('Agregar primer servicio'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ServiceAction { edit, delete }

class _ServiceDraft {
  const _ServiceDraft({
    required this.name,
    required this.durationMinutes,
    required this.price,
  });

  final String name;
  final int durationMinutes;
  final double price;
}

class _CreateServiceBottomSheet extends StatefulWidget {
  const _CreateServiceBottomSheet({required this.salonId});

  final String salonId;

  @override
  State<_CreateServiceBottomSheet> createState() =>
      _CreateServiceBottomSheetState();
}

class _CreateServiceBottomSheetState extends State<_CreateServiceBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  final _priceController = TextEditingController(text: '50');
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await getIt<SalonRepository>().createService(
        salonId: widget.salonId,
        name: _nameController.text.trim(),
        durationMinutes: int.parse(_durationController.text.trim()),
        price: double.parse(_priceController.text.trim().replaceAll(',', '.')),
        idempotencyKey:
            'createService_${widget.salonId}_${DateTime.now().microsecondsSinceEpoch}',
      );
      if (mounted) Navigator.of(context).pop(true);
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: bottomInset + AppSpacing.md,
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agregar servicio',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  maxLength: SalonInputLimits.serviceNameMaxLength,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: validateServiceName,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _durationController,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duración (min)',
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        validator: validateServiceDuration,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        textInputAction: TextInputAction.done,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Precio'),
                        inputFormatters: servicePriceInputFormatters,
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).unfocus(),
                        validator: validateServicePrice,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                PillButtonWidget(
                  label: 'Agregar servicio',
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditServiceDialog extends StatefulWidget {
  const _EditServiceDialog({required this.service});

  final Service service;

  @override
  State<_EditServiceDialog> createState() => _EditServiceDialogState();
}

class _EditServiceDialogState extends State<_EditServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _durationController;
  late final TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    final service = widget.service;
    _nameController = TextEditingController(text: service.name);
    _durationController = TextEditingController(
      text: service.durationMinutes.toString(),
    );
    _priceController = TextEditingController(text: service.price.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      _ServiceDraft(
        name: _nameController.text.trim(),
        durationMinutes: int.parse(_durationController.text.trim()),
        price: double.parse(_priceController.text.trim().replaceAll(',', '.')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: AlertDialog(
        title: const Text('Editar servicio'),
        content: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  maxLength: SalonInputLimits.serviceNameMaxLength,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: validateServiceName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _durationController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duración (min)',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  validator: validateServiceDuration,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  textInputAction: TextInputAction.done,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Precio (${widget.service.currency})',
                  ),
                  inputFormatters: servicePriceInputFormatters,
                  onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                  validator: validateServicePrice,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(onPressed: _save, child: const Text('Guardar')),
        ],
      ),
    );
  }
}

class _InlineProgressLabel extends StatelessWidget {
  const _InlineProgressLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(child: Text(label)),
      ],
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.value,
    this.muted = false,
  });

  final IconData icon;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = muted
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
