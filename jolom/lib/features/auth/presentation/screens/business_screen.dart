import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/providers/app_config_provider.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';
import 'package:jolom/features/salon/domain/repositories/salon_repository.dart';
import 'package:jolom/features/salon/domain/validation/salon_input_limits.dart';
import 'package:jolom/shared/widgets/app_modal_bottom_sheet.dart';
import 'package:jolom/shared/widgets/pill_button_widget.dart';
import 'package:jolom/shared/widgets/soft_card_widget.dart';

/// Acceso a la creación de negocio o al modo trabajo según la membresía.
class BusinessScreen extends ConsumerWidget {
  const BusinessScreen({super.key});

  void _openCreateSalonSheet(BuildContext context) {
    showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _CreateSalonBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membershipAsync = ref.watch(membershipProvider);
    final canCreateSalonAsync = ref.watch(canCreateSalonProvider);
    final membership = membershipAsync.value;
    final hasActiveMembership = membership != null && membership.isActive;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi negocio')),
      body: ListView(
        padding: appScrollPadding(context, horizontal: 16, vertical: 16),
        children: [
          if (hasActiveMembership)
            SoftCardWidget(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    membership.isOwner
                        ? 'Gestiona tu peluquería'
                        : 'Tu espacio de trabajo',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    membership.isOwner
                        ? 'Administra tu negocio, equipo, servicios y agenda.'
                        : 'Administra tu agenda y tus citas.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  PillButtonWidget(
                    label: 'Ir a modo trabajo',
                    icon: Icons.work_outline_rounded,
                    onPressed: () {
                      ref.read(appModeProvider.notifier).setMode(AppMode.work);
                      context.go('/work');
                    },
                  ),
                ],
              ),
            )
          else if (canCreateSalonAsync.value == true)
            SoftCardWidget(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.add_business_outlined,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '¿Tienes un negocio?',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crea tu peluquería con la misma cuenta. Conservarás el modo cliente.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  PillButtonWidget(
                    label: 'Crear mi peluquería',
                    icon: Icons.storefront_outlined,
                    onPressed: () => _openCreateSalonSheet(context),
                  ),
                ],
              ),
            )
          else if (membershipAsync.isLoading || canCreateSalonAsync.isLoading)
            const SoftCardWidget(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else
            SoftCardWidget(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 32,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Opciones de negocio no disponibles',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Inténtalo nuevamente más tarde.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Formulario de alta de peluquería en un bottom sheet.
class _CreateSalonBottomSheet extends ConsumerStatefulWidget {
  const _CreateSalonBottomSheet();

  @override
  ConsumerState<_CreateSalonBottomSheet> createState() =>
      _CreateSalonBottomSheetState();
}

class _CreateSalonBottomSheetState
    extends ConsumerState<_CreateSalonBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _salonNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _creating = false;

  bool get _canCreateSalon {
    final name = _salonNameCtrl.text.trim();
    return name.isNotEmpty &&
        SalonInputLimits.isTextWithinLimit(
          name,
          SalonInputLimits.salonNameMaxLength,
        ) &&
        SalonInputLimits.isTextWithinLimit(
          _phoneCtrl.text.trim(),
          SalonInputLimits.salonPhoneMaxLength,
        ) &&
        SalonInputLimits.isTextWithinLimit(
          _addressCtrl.text.trim(),
          SalonInputLimits.salonAddressMaxLength,
        );
  }

  @override
  void initState() {
    super.initState();
    _salonNameCtrl.addListener(_onFormChanged);
    _phoneCtrl.addListener(_onFormChanged);
    _addressCtrl.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _salonNameCtrl.removeListener(_onFormChanged);
    _phoneCtrl.removeListener(_onFormChanged);
    _addressCtrl.removeListener(_onFormChanged);
    _salonNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _createSalon() async {
    if (_creating || !_canCreateSalon || !_formKey.currentState!.validate()) {
      return;
    }
    final name = _salonNameCtrl.text.trim();
    setState(() => _creating = true);
    try {
      final salon = await getIt<SalonRepository>().createSalon(
        name: name,
        contactPhone: _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
      );
      ref.invalidate(membershipProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Peluquería creada. Completa ahora su configuración.'),
        ),
      );
      ref.read(appModeProvider.notifier).setMode(AppMode.work);
      context.go(
        Uri(
          path: '/onboarding/salon/setup',
          queryParameters: {'salonId': salon.id},
        ).toString(),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: bottomInset + 16),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Crear mi peluquería',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Ingresa los datos básicos. Después agregarás una foto, la '
                'ubicación, tu primer servicio y el horario.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _salonNameCtrl,
                textInputAction: TextInputAction.next,
                maxLength: SalonInputLimits.salonNameMaxLength,
                decoration: const InputDecoration(
                  labelText: 'Nombre del negocio',
                ),
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) return 'Ingresa el nombre del negocio';
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
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                maxLength: SalonInputLimits.salonPhoneMaxLength,
                decoration: const InputDecoration(labelText: 'Teléfono'),
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
                textInputAction: TextInputAction.done,
                maxLength: SalonInputLimits.salonAddressMaxLength,
                onFieldSubmitted: (_) => _createSalon(),
                decoration: const InputDecoration(labelText: 'Dirección'),
                validator: (value) =>
                    SalonInputLimits.isTextWithinLimit(
                      value?.trim() ?? '',
                      SalonInputLimits.salonAddressMaxLength,
                    )
                    ? null
                    : 'Máximo ${SalonInputLimits.salonAddressMaxLength} caracteres',
              ),
              const SizedBox(height: 20),
              PillButtonWidget(
                label: 'Crear mi peluquería',
                loading: _creating,
                onPressed: _canCreateSalon ? _createSalon : null,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
