import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/providers/session_provider.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';
import 'package:jolom/features/appointment/domain/entities/availability_entity.dart';
import 'package:jolom/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:jolom/features/appointment/presentation/utils/availability_time_utils.dart';
import 'package:jolom/features/appointment/presentation/widgets/availability_days_editor_widget.dart';
import 'package:jolom/features/salon/domain/entities/salon_entity.dart';
import 'package:jolom/features/salon/domain/repositories/salon_repository.dart';
import 'package:jolom/features/salon/presentation/widgets/salon_onboarding_header_widget.dart';
import 'package:jolom/shared/widgets/pill_button_widget.dart';
import 'package:jolom/shared/widgets/soft_card_widget.dart';

/// Último paso del alta: guarda el horario inicial y publica el negocio.
class ConfigureInitialScheduleScreen extends ConsumerStatefulWidget {
  const ConfigureInitialScheduleScreen({
    required this.salonId,
    this.barberId,
    super.key,
  });

  final String salonId;

  /// Inyectable para pruebas; en la aplicación se usa la sesión activa.
  final String? barberId;

  @override
  ConsumerState<ConfigureInitialScheduleScreen> createState() =>
      _ConfigureInitialScheduleScreenState();
}

class _ConfigureInitialScheduleScreenState
    extends ConsumerState<ConfigureInitialScheduleScreen> {
  final Map<String, bool> _enabled = {
    for (final day in availabilityWeekDays) day: day != 'sat',
  };
  final Map<String, TimeOfDay> _dayStart = {
    for (final day in availabilityWeekDays)
      day: const TimeOfDay(hour: 9, minute: 0),
  };
  final Map<String, TimeOfDay> _dayEnd = {
    for (final day in availabilityWeekDays)
      day: const TimeOfDay(hour: 18, minute: 0),
  };

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  bool _showScheduleError = false;
  late final UnsavedChangesNotifier _unsavedChangesNotifier;

  String? get _barberId =>
      widget.barberId ?? ref.read(sessionProvider).value?.id;

  bool get _hasOpenDay =>
      availabilityWeekDays.any((day) => _enabled[day] == true);

  bool get _hasValidSchedule {
    if (!_hasOpenDay) return false;
    for (final day in availabilityWeekDays) {
      if (_enabled[day] != true) continue;
      if (availabilityTimeToMinutes(_dayEnd[day]!) <=
          availabilityTimeToMinutes(_dayStart[day]!)) {
        return false;
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _unsavedChangesNotifier = ref.read(
      initialScheduleUnsavedChangesProvider.notifier,
    );
    _load();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
    _unsavedChangesNotifier.markDirty();
  }

  Future<void> _load() async {
    final barberId = _barberId;
    if (barberId == null || barberId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final availability = await getIt<AppointmentRepository>().getAvailability(
        barberId,
      );
      if (!mounted) return;
      final weeklyHours = availability?.weeklyHours;
      if (hasAnyOpenAvailabilityDay(weeklyHours)) {
        for (final day in availabilityWeekDays) {
          final raw = weeklyHours?[day];
          if (raw is! Map || raw['start'] == null || raw['end'] == null) {
            _enabled[day] = false;
            continue;
          }
          final dayMap = Map<String, dynamic>.from(raw);
          final start = parseAvailabilityHm(dayMap['start']);
          final end = parseAvailabilityHm(dayMap['end']);
          _enabled[day] = start != null && end != null;
          if (start != null) _dayStart[day] = start;
          if (end != null) _dayEnd[day] = end;
        }
      }
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _pickDayTime(String day, {required bool isStart}) async {
    final initial = isStart ? _dayStart[day]! : _dayEnd[day]!;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;

    if (!isStart &&
        availabilityTimeToMinutes(picked) <=
            availabilityTimeToMinutes(_dayStart[day]!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La hora final debe ser posterior al inicio.'),
        ),
      );
      return;
    }

    setState(() {
      if (isStart) {
        _dayStart[day] = picked;
        if (availabilityTimeToMinutes(_dayEnd[day]!) <=
            availabilityTimeToMinutes(picked)) {
          final next = availabilityTimeToMinutes(picked) + 60;
          _dayEnd[day] = TimeOfDay(hour: (next ~/ 60) % 24, minute: next % 60);
        }
      } else {
        _dayEnd[day] = picked;
      }
    });
    _markDirty();
  }

  Map<String, dynamic>? _validatedWeeklyHours() {
    if (!_hasOpenDay) {
      setState(() => _showScheduleError = true);
      return null;
    }

    final weekly = <String, dynamic>{};
    for (final day in availabilityWeekDays) {
      if (_enabled[day] != true) {
        weekly[day] = null;
        continue;
      }
      if (availabilityTimeToMinutes(_dayEnd[day]!) <=
          availabilityTimeToMinutes(_dayStart[day]!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Revisa el horario de ${availabilityWeekDayLabels[day]}.',
            ),
          ),
        );
        return null;
      }
      weekly[day] = {
        'start': formatAvailabilityHm(_dayStart[day]!),
        'end': formatAvailabilityHm(_dayEnd[day]!),
      };
    }
    return weekly;
  }

  Future<void> _saveAndPublish() async {
    final barberId = _barberId;
    if (_saving || barberId == null || barberId.isEmpty) return;
    final weeklyHours = _validatedWeeklyHours();
    if (weeklyHours == null) return;

    setState(() => _saving = true);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    try {
      await getIt<AppointmentRepository>().setAvailability(
        barberId: barberId,
        weeklyHours: weeklyHours,
        idempotencyKey: 'initialAvailability_${widget.salonId}_$timestamp',
      );
      await getIt<SalonRepository>().setSalonPublishStatus(
        salonId: widget.salonId,
        publishStatus: SalonPublishStatus.published,
        idempotencyKey: 'publishAfterOnboarding_${widget.salonId}_$timestamp',
      );
      if (!mounted) return;
      setState(() => _dirty = false);
      _unsavedChangesNotifier.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu negocio ya está publicado.')),
      );
      context.go('/work/salon');
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

    if (_barberId == null || widget.salonId.trim().isEmpty) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: Text('No se pudo cargar la configuración.')),
        ),
      );
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
            value: 1,
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
          const SalonOnboardingHeaderWidget(
            step: 3,
            title: 'Define tu horario',
            description:
                'Activa los días en que atenderás. Al terminar, tu negocio '
                'quedará publicado y listo para recibir reservaciones.',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_showScheduleError) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: AppRadius.cardCompact,
              ),
              child: Text(
                'Activa al menos un día para poder publicar tu negocio.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          SoftCardWidget(
            child: AvailabilityDaysEditorWidget(
              days: availabilityWeekDays,
              labels: availabilityWeekDayLabels,
              enabled: _enabled,
              dayStart: _dayStart,
              dayEnd: _dayEnd,
              onDayEnabledChanged: (day, enabled) {
                setState(() {
                  _enabled[day] = enabled;
                  _showScheduleError = !_hasOpenDay;
                });
                _markDirty();
              },
              onPickDayTime: _pickDayTime,
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
          label: 'Guardar y publicar',
          icon: Icons.rocket_launch_rounded,
          loading: _saving,
          onPressed: _hasValidSchedule ? _saveAndPublish : null,
        ),
      ),
    );
  }
}
