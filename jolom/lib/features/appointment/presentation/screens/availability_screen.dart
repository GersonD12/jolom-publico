import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/providers/session_provider.dart';
import 'package:jolom/features/appointment/domain/entities/availability_entity.dart';
import 'package:jolom/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:jolom/shared/widgets/discard_unsaved_changes_dialog.dart';

import '../utils/availability_time_utils.dart';
import '../widgets/add_absence_dialog_widget.dart';
import '../widgets/availability_absences_tab_widget.dart';
import '../widgets/availability_lunch_tab_widget.dart';
import '../widgets/availability_schedule_tab_widget.dart';

/// Configuración de disponibilidad semanal y excepciones del peluquero.
class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _selectedTabIndex = 0;
  bool _handlingTabChange = false;

  final Map<String, bool> _enabled = {
    for (final d in availabilityWeekDays) d: d != 'sun',
  };
  final Map<String, TimeOfDay> _dayStart = {
    for (final d in availabilityWeekDays)
      d: const TimeOfDay(hour: 9, minute: 0),
  };
  final Map<String, TimeOfDay> _dayEnd = {
    for (final d in availabilityWeekDays)
      d: const TimeOfDay(hour: 18, minute: 0),
  };
  bool _lunchEnabled = false;
  TimeOfDay _lunchStart = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _lunchEnd = const TimeOfDay(hour: 14, minute: 0);
  bool _saving = false;
  bool _loading = true;
  bool _scheduleDirty = false;
  bool _lunchDirty = false;
  List<AvailabilityException> _exceptions = const [];

  late final UnsavedChangesNotifier _unsavedChangesNotifier;

  Map<String, bool> _savedEnabled = {};
  Map<String, TimeOfDay> _savedDayStart = {};
  Map<String, TimeOfDay> _savedDayEnd = {};
  bool _savedLunchEnabled = false;
  TimeOfDay _savedLunchStart = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _savedLunchEnd = const TimeOfDay(hour: 14, minute: 0);

  Map<String, dynamic> get _lunchBreakMap => {
    'start': formatAvailabilityHm(_lunchStart),
    'end': formatAvailabilityHm(_lunchEnd),
    'reason': 'Almuerzo',
  };

  @override
  void initState() {
    super.initState();
    _unsavedChangesNotifier = ref.read(
      availabilityUnsavedChangesProvider.notifier,
    );
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _syncUnsavedChangesProvider() {
    _unsavedChangesNotifier.setDirty(_hasUnsavedChanges);
  }

  void _markScheduleDirty() {
    setState(() => _scheduleDirty = true);
    _syncUnsavedChangesProvider();
  }

  void _markLunchDirty() {
    setState(() => _lunchDirty = true);
    _syncUnsavedChangesProvider();
  }

  void _clearDirtyAfterSave() {
    setState(() {
      _scheduleDirty = false;
      _lunchDirty = false;
    });
    _syncUnsavedChangesProvider();
  }

  bool get _hasUnsavedChanges => _scheduleDirty || _lunchDirty;

  void _captureSavedAvailability() {
    _savedEnabled = Map.of(_enabled);
    _savedDayStart = Map.of(_dayStart);
    _savedDayEnd = Map.of(_dayEnd);
    _savedLunchEnabled = _lunchEnabled;
    _savedLunchStart = _lunchStart;
    _savedLunchEnd = _lunchEnd;
  }

  void _discardUnsavedChanges() {
    setState(() {
      _enabled
        ..clear()
        ..addAll(_savedEnabled);
      _dayStart
        ..clear()
        ..addAll(_savedDayStart);
      _dayEnd
        ..clear()
        ..addAll(_savedDayEnd);
      _lunchEnabled = _savedLunchEnabled;
      _lunchStart = _savedLunchStart;
      _lunchEnd = _savedLunchEnd;
      _scheduleDirty = false;
      _lunchDirty = false;
    });
    _syncUnsavedChangesProvider();
  }

  void _onTabChanged() {
    if (_handlingTabChange || _tabs.index == _selectedTabIndex) return;

    final nextTabIndex = _tabs.index;
    if (!_hasUnsavedChanges) {
      _selectedTabIndex = nextTabIndex;
      return;
    }

    _handlingTabChange = true;
    _tabs.index = _selectedTabIndex;
    _confirmTabChange(nextTabIndex);
  }

  Future<void> _confirmTabChange(int nextTabIndex) async {
    final discard = await showDiscardUnsavedChangesDialog(context);

    if (!mounted) return;
    if (discard) {
      _discardUnsavedChanges();
      _selectedTabIndex = nextTabIndex;
      _tabs.index = nextTabIndex;
    }
    _handlingTabChange = false;
  }

  Future<void> _load() async {
    final uid = ref.read(sessionProvider).value?.id;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final avail = await getIt<AppointmentRepository>().getAvailability(uid);
      if (!mounted) return;
      if (avail == null) {
        setState(() {
          _captureSavedAvailability();
          _loading = false;
        });
        return;
      }
      var lunch = false;
      var lunchStart = _lunchStart;
      var lunchEnd = _lunchEnd;
      setState(() {
        for (final d in availabilityWeekDays) {
          final raw = avail.weeklyHours[d];
          if (raw is! Map || raw['start'] == null) {
            _enabled[d] = false;
            continue;
          }
          final dayMap = Map<String, dynamic>.from(raw);
          _enabled[d] = true;
          final start = parseAvailabilityHm(dayMap['start']);
          final end = parseAvailabilityHm(dayMap['end']);
          if (start != null) _dayStart[d] = start;
          if (end != null) _dayEnd[d] = end;
          if (!lunch) {
            final breaks = dayMap['breaks'];
            if (breaks is List && breaks.isNotEmpty) {
              final b = breaks.first;
              if (b is Map) {
                final bStart = parseAvailabilityHm(b['start']);
                final bEnd = parseAvailabilityHm(b['end']);
                if (bStart != null && bEnd != null) {
                  lunch = true;
                  lunchStart = bStart;
                  lunchEnd = bEnd;
                }
              }
            }
          }
        }
        _lunchEnabled = lunch;
        _lunchStart = lunchStart;
        _lunchEnd = lunchEnd;
        _exceptions = List.of(avail.exceptions);
        _captureSavedAvailability();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDayTime(String day, {required bool isStart}) async {
    final initial = isStart ? _dayStart[day]! : _dayEnd[day]!;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    var changed = false;
    setState(() {
      if (isStart) {
        _dayStart[day] = picked;
        if (availabilityTimeToMinutes(_dayEnd[day]!) <=
            availabilityTimeToMinutes(_dayStart[day]!)) {
          final next = availabilityTimeToMinutes(_dayStart[day]!) + 60;
          _dayEnd[day] = TimeOfDay(hour: (next ~/ 60) % 24, minute: next % 60);
        }
        changed = true;
      } else {
        if (availabilityTimeToMinutes(picked) <=
            availabilityTimeToMinutes(_dayStart[day]!)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La hora final debe ser posterior al inicio.'),
            ),
          );
          return;
        }
        _dayEnd[day] = picked;
        changed = true;
      }
    });
    if (changed) _markScheduleDirty();
  }

  Future<void> _pickLunchTime({required bool isStart}) async {
    final initial = isStart ? _lunchStart : _lunchEnd;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    var changed = false;
    setState(() {
      if (isStart) {
        _lunchStart = picked;
        if (availabilityTimeToMinutes(_lunchEnd) <=
            availabilityTimeToMinutes(_lunchStart)) {
          final next = availabilityTimeToMinutes(_lunchStart) + 60;
          _lunchEnd = TimeOfDay(hour: (next ~/ 60) % 24, minute: next % 60);
        }
        changed = true;
      } else {
        if (availabilityTimeToMinutes(picked) <=
            availabilityTimeToMinutes(_lunchStart)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La hora final debe ser posterior al inicio.'),
            ),
          );
          return;
        }
        _lunchEnd = picked;
        changed = true;
      }
    });
    if (changed) _markLunchDirty();
  }

  /// Persiste días abiertos + almuerzo (mismo documento weeklyHours).
  Future<void> _saveWeekly({required String successMessage}) async {
    final uid = ref.read(sessionProvider).value?.id;
    if (uid == null) return;
    if (_lunchEnabled &&
        availabilityTimeToMinutes(_lunchEnd) <=
            availabilityTimeToMinutes(_lunchStart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisa el rango de almuerzo (inicio < fin).'),
        ),
      );
      return;
    }
    for (final d in availabilityWeekDays) {
      if (_enabled[d] != true) continue;
      if (availabilityTimeToMinutes(_dayEnd[d]!) <=
          availabilityTimeToMinutes(_dayStart[d]!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Revisa el horario de ${availabilityWeekDayLabels[d]} '
              '(inicio < fin).',
            ),
          ),
        );
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final weekly = <String, dynamic>{};
      final lunch = _lunchBreakMap;
      for (final d in availabilityWeekDays) {
        if (_enabled[d] == true) {
          weekly[d] = {
            'start': formatAvailabilityHm(_dayStart[d]!),
            'end': formatAvailabilityHm(_dayEnd[d]!),
            if (_lunchEnabled) 'breaks': [lunch],
          };
        } else {
          weekly[d] = null;
        }
      }
      await getIt<AppointmentRepository>().setAvailability(
        barberId: uid,
        weeklyHours: weekly,
      );
      if (!mounted) return;
      _captureSavedAvailability();
      _clearDirtyAfterSave();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showAddExceptionDialog() async {
    final uid = ref.read(sessionProvider).value?.id;
    if (uid == null) return;

    final result = await showAddAbsenceDialog(context);
    if (result == null || !mounted) return;

    if (!result.allDay &&
        availabilityTimeToMinutes(result.timeEnd) <=
            availabilityTimeToMinutes(result.timeStart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La hora fin debe ser posterior a la de inicio.'),
        ),
      );
      return;
    }

    final repo = getIt<AppointmentRepository>();
    try {
      if (result.allDay) {
        await repo.createAvailabilityBlock(
          barberId: uid,
          start: result.dayStart,
          end: result.dayEnd.add(const Duration(days: 1)),
          type: 'timeOff',
          reason: result.reason,
        );
      } else {
        var day = result.dayStart;
        while (!day.isAfter(result.dayEnd)) {
          final start = DateTime(
            day.year,
            day.month,
            day.day,
            result.timeStart.hour,
            result.timeStart.minute,
          );
          final end = DateTime(
            day.year,
            day.month,
            day.day,
            result.timeEnd.hour,
            result.timeEnd.minute,
          );
          await repo.createAvailabilityBlock(
            barberId: uid,
            start: start,
            end: end,
            type: 'block',
            reason: result.reason,
          );
          day = day.add(const Duration(days: 1));
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ausencia añadida.')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    }
  }

  Future<void> _deleteException(AvailabilityException ex) async {
    final uid = ref.read(sessionProvider).value?.id;
    if (uid == null) return;
    try {
      await getIt<AppointmentRepository>().deleteAvailabilityException(
        barberId: uid,
        exceptionId: ex.id,
      );
      if (!mounted) return;
      setState(() {
        _exceptions = _exceptions.where((e) => e.id != ex.id).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(membershipProvider).value;
    if (membership == null || !membership.isActive) {
      return const Scaffold(
        body: Center(child: Text('Necesitas pertenencia activa.')),
      );
    }

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Disponibilidad'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Horario'),
            Tab(text: 'Almuerzo'),
            Tab(text: 'Ausencias'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          RefreshIndicator(
            onRefresh: _load,
            child: AvailabilityScheduleTabWidget(
              days: availabilityWeekDays,
              labels: availabilityWeekDayLabels,
              enabled: _enabled,
              dayStart: _dayStart,
              dayEnd: _dayEnd,
              dirty: _scheduleDirty,
              saving: _saving,
              onDayEnabledChanged: (day, value) {
                setState(() => _enabled[day] = value);
                _markScheduleDirty();
              },
              onPickDayTime: _pickDayTime,
              onSave: () => _saveWeekly(successMessage: 'Horario guardado.'),
            ),
          ),
          RefreshIndicator(
            onRefresh: _load,
            child: AvailabilityLunchTabWidget(
              enabled: _lunchEnabled,
              start: _lunchStart,
              end: _lunchEnd,
              dirty: _lunchDirty,
              saving: _saving,
              onEnabledChanged: (v) {
                setState(() => _lunchEnabled = v);
                _markLunchDirty();
              },
              onPickTime: _pickLunchTime,
              onSave: () => _saveWeekly(successMessage: 'Almuerzo guardado.'),
            ),
          ),
          RefreshIndicator(
            onRefresh: _load,
            child: AvailabilityAbsencesTabWidget(
              exceptions: _exceptions,
              onAdd: _showAddExceptionDialog,
              onDelete: _deleteException,
            ),
          ),
        ],
      ),
    );
  }
}
