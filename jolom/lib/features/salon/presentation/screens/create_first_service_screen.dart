import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';
import 'package:jolom/features/salon/domain/entities/service_entity.dart';
import 'package:jolom/features/salon/domain/repositories/salon_repository.dart';
import 'package:jolom/features/salon/domain/validation/salon_input_limits.dart';
import 'package:jolom/features/salon/presentation/utils/service_form_utils.dart';
import 'package:jolom/features/salon/presentation/widgets/salon_onboarding_header_widget.dart';
import 'package:jolom/shared/widgets/pill_button_widget.dart';
import 'package:jolom/shared/widgets/soft_card_widget.dart';

/// Segundo paso del alta: crea o confirma el primer servicio activo.
class CreateFirstServiceScreen extends ConsumerStatefulWidget {
  const CreateFirstServiceScreen({required this.salonId, super.key});

  final String salonId;

  @override
  ConsumerState<CreateFirstServiceScreen> createState() =>
      _CreateFirstServiceScreenState();
}

class _CreateFirstServiceScreenState
    extends ConsumerState<CreateFirstServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  final _priceController = TextEditingController(text: '50');
  Service? _existingService;
  bool _loading = true;
  bool _saving = false;

  late final UnsavedChangesNotifier _unsavedChangesNotifier;

  bool get _hasUnsavedChanges =>
      _existingService == null &&
      (_nameController.text.isNotEmpty ||
          _durationController.text != '30' ||
          _priceController.text != '50');

  bool get _canContinue =>
      _existingService != null ||
      (validateServiceName(_nameController.text) == null &&
          validateServiceDuration(_durationController.text) == null &&
          validateServicePrice(_priceController.text) == null);

  @override
  void initState() {
    super.initState();
    _unsavedChangesNotifier = ref.read(
      firstServiceUnsavedChangesProvider.notifier,
    );
    _nameController.addListener(_onFormChanged);
    _durationController.addListener(_onFormChanged);
    _priceController.addListener(_onFormChanged);
    _load();
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFormChanged);
    _durationController.removeListener(_onFormChanged);
    _priceController.removeListener(_onFormChanged);
    _nameController.dispose();
    _durationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    _unsavedChangesNotifier.setDirty(_hasUnsavedChanges);
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final salonId = widget.salonId.trim();
    if (salonId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final services = await getIt<SalonRepository>().listServices(salonId);
      if (!mounted) return;
      Service? activeService;
      for (final service in services) {
        if (service.isActive) {
          activeService = service;
          break;
        }
      }
      setState(() {
        _existingService = activeService;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  void _continueToSchedule() {
    _unsavedChangesNotifier.clear();
    context.go(
      Uri(
        path: '/onboarding/salon/schedule',
        queryParameters: {'salonId': widget.salonId},
      ).toString(),
    );
  }

  Future<void> _save() async {
    _dismissKeyboard();
    if (_existingService != null) {
      _continueToSchedule();
      return;
    }
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
      if (!mounted) return;
      _continueToSchedule();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _dismissKeyboard() => FocusScope.of(context).unfocus();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
            value: 2 / 3,
            minHeight: 4,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissKeyboard,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: appScrollPadding(
            context,
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
            bottom: 112,
          ),
          children: [
            const SalonOnboardingHeaderWidget(
              step: 2,
              title: 'Crea tu primer servicio',
              description:
                  'Indica qué podrán reservar tus clientes. Podrás agregar más '
                  'servicios y editarlos después.',
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_existingService case final service?)
              SoftCardWidget(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.primary,
                      child: const Icon(Icons.check_rounded),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${service.durationMinutes} min · '
                            '${service.currency} ${service.price.toStringAsFixed(2)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              SoftCardWidget(
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detalles del servicio',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        maxLength: SalonInputLimits.serviceNameMaxLength,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del servicio',
                          hintText: 'Ej. Corte de cabello',
                          prefixIcon: Icon(Icons.content_cut_rounded),
                        ),
                        validator: validateServiceName,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _durationController,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Duración',
                                suffixText: 'min',
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              validator: validateServiceDuration,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              textInputAction: TextInputAction.done,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Precio',
                              ),
                              inputFormatters: servicePriceInputFormatters,
                              onFieldSubmitted: (_) => _dismissKeyboard(),
                              validator: validateServicePrice,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: PillButtonWidget(
          label: _existingService == null
              ? 'Guardar y continuar'
              : 'Continuar al horario',
          icon: Icons.arrow_forward_rounded,
          loading: _saving,
          onPressed: _canContinue ? _save : null,
        ),
      ),
    );
  }
}
