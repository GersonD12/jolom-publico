import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/features/appointment/domain/entities/busy_interval_entity.dart';
import 'package:jolom/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:jolom/features/appointment/presentation/utils/availability_time_utils.dart';
import 'package:jolom/shared/widgets/pill_button_widget.dart';

import 'booking_schedule_picker_widget.dart';
import 'booking_service_summary_widget.dart';
import 'day_timeline_picker_widget.dart';

/// Selección de día y franja horaria para completar la reserva.
class BookingScheduleSheet extends StatefulWidget {
  const BookingScheduleSheet({
    required this.salonId,
    required this.serviceId,
    required this.barberId,
    required this.durationMinutes,
    required this.serviceName,
    required this.priceLabel,
    required this.onConfirm,
    this.initialWeeklyHours,
    super.key,
  });

  final String salonId;
  final String serviceId;
  final String barberId;
  final int durationMinutes;
  final String serviceName;
  final String priceLabel;
  final Map<String, dynamic>? initialWeeklyHours;
  final Future<void> Function(PendingBooking pending) onConfirm;

  @override
  State<BookingScheduleSheet> createState() => _BookingScheduleSheetState();
}

class _BookingScheduleSheetState extends State<BookingScheduleSheet> {
  DateTime? _selectedSlot;
  late DateTime _selectedDay;
  bool _slotValid = false;
  bool _submitting = false;

  List<BusyInterval> _busyIntervals = const [];
  bool _dayClosed = false;
  DateTime? _dayOpen;
  DateTime? _dayClose;
  bool _scheduleKnown = false;
  bool _busyLoading = false;
  String? _busyError;
  Set<DateTime>? _availableStarts;
  int _busyRequestId = 0;
  Timer? _loadDebounce;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _applyProvisionalSchedule(_selectedDay);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBusy());
  }

  @override
  void dispose() {
    _loadDebounce?.cancel();
    _busyRequestId++;
    super.dispose();
  }

  /// Pinta inmediatamente el horario público ya cargado en la ficha del salón.
  /// La respuesta del backend reemplaza después esta vista provisional con el
  /// horario del peluquero, excepciones y citas ocupadas autoritativas.
  void _applyProvisionalSchedule(DateTime day) {
    final weeklyHours = widget.initialWeeklyHours;
    final dayKey = availabilityWeekDays[day.weekday - 1];
    final rawDay = weeklyHours?[dayKey];

    _busyIntervals = const [];
    _availableStarts = null;
    _busyError = null;

    if (weeklyHours == null || weeklyHours.isEmpty) {
      _scheduleKnown = false;
      _dayClosed = false;
      _dayOpen = null;
      _dayClose = null;
      return;
    }

    _scheduleKnown = true;
    if (rawDay is! Map) {
      _dayClosed = true;
      _dayOpen = null;
      _dayClose = null;
      return;
    }

    final dayMap = Map<String, dynamic>.from(rawDay);
    final start = parseAvailabilityHm(dayMap['start']);
    final end = parseAvailabilityHm(dayMap['end']);
    if (start == null || end == null) {
      _dayClosed = true;
      _dayOpen = null;
      _dayClose = null;
      return;
    }

    final open = DateTime(
      day.year,
      day.month,
      day.day,
      start.hour,
      start.minute,
    );
    final close = DateTime(day.year, day.month, day.day, end.hour, end.minute);
    if (!close.isAfter(open)) {
      _dayClosed = true;
      _dayOpen = null;
      _dayClose = null;
      return;
    }

    final provisionalBreaks = <BusyInterval>[];
    final rawBreaks = dayMap['breaks'];
    if (rawBreaks is List) {
      for (final rawBreak in rawBreaks) {
        if (rawBreak is! Map) continue;
        final breakStart = parseAvailabilityHm(rawBreak['start']);
        final breakEnd = parseAvailabilityHm(rawBreak['end']);
        if (breakStart == null || breakEnd == null) continue;
        final intervalStart = DateTime(
          day.year,
          day.month,
          day.day,
          breakStart.hour,
          breakStart.minute,
        );
        final intervalEnd = DateTime(
          day.year,
          day.month,
          day.day,
          breakEnd.hour,
          breakEnd.minute,
        );
        if (intervalEnd.isAfter(intervalStart)) {
          provisionalBreaks.add(
            BusyInterval(start: intervalStart, end: intervalEnd),
          );
        }
      }
    }

    _dayClosed = false;
    _dayOpen = open;
    _dayClose = close;
    _busyIntervals = provisionalBreaks;
  }

  Future<void> _loadBusy() async {
    final requestId = ++_busyRequestId;
    final dayStart = _selectedDay;
    setState(() {
      _busyLoading = true;
      _busyError = null;
    });
    try {
      final dayEnd = dayStart.add(const Duration(days: 1));
      final canvas = await getIt<AppointmentRepository>().getDayBusyIntervals(
        salonId: widget.salonId,
        barberId: widget.barberId,
        dayStart: dayStart,
        dayEnd: dayEnd,
        serviceId: widget.serviceId,
      );
      if (!mounted || requestId != _busyRequestId) return;

      DateTime? open;
      DateTime? close;
      if (!canvas.isClosed &&
          canvas.dayOpenMinutes != null &&
          canvas.dayCloseMinutes != null) {
        open = dayStart.add(Duration(minutes: canvas.dayOpenMinutes!));
        close = dayStart.add(Duration(minutes: canvas.dayCloseMinutes!));
      }

      setState(() {
        _busyIntervals = canvas.intervals;
        _scheduleKnown = true;
        _dayClosed = canvas.isClosed;
        _dayOpen = open;
        _dayClose = close;
        _availableStarts = canvas.availableStarts;
        _busyLoading = false;
        if (canvas.isClosed) {
          _selectedSlot = null;
          _slotValid = false;
        }
      });
    } catch (e) {
      if (!mounted || requestId != _busyRequestId) return;
      setState(() {
        _busyLoading = false;
        _busyError = userFacingError(e);
      });
    }
  }

  void _onDaySelected(DateTime day) {
    _busyRequestId++;
    setState(() {
      _selectedDay = DateTime(day.year, day.month, day.day);
      _applyProvisionalSchedule(_selectedDay);
      _busyLoading = true;
      final slot = _selectedSlot;
      if (slot != null &&
          (slot.year != day.year ||
              slot.month != day.month ||
              slot.day != day.day)) {
        _selectedSlot = null;
        _slotValid = false;
      }
    });
    _loadDebounce?.cancel();
    _loadDebounce = Timer(const Duration(milliseconds: 180), _loadBusy);
  }

  Future<void> _onReserve() async {
    final slot = _selectedSlot;
    if (slot == null || !_slotValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Elige un horario libre.')));
      return;
    }

    final pending = PendingBooking(
      salonId: widget.salonId,
      serviceId: widget.serviceId,
      barberId: widget.barberId,
      startAt: slot,
    );

    setState(() => _submitting = true);
    try {
      await widget.onConfirm(pending);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return SizedBox(
      height: maxHeight,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: bottomInset + safeBottom + AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Horario', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            BookingServiceSummaryWidget(
              name: widget.serviceName,
              durationMinutes: widget.durationMinutes,
              priceLabel: widget.priceLabel,
            ),
            const SizedBox(height: AppSpacing.md),
            BookingSchedulePickerWidget(
              selectedDay: _selectedDay,
              onDaySelected: _onDaySelected,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_busyLoading) const LinearProgressIndicator(),
            if (_busyLoading) const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_busyError != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'No se pudieron actualizar los espacios ocupados.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadBusy,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: !_scheduleKnown
                        ? Text(
                            'Consultando disponibilidad…',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          )
                        : _dayClosed || _dayOpen == null || _dayClose == null
                        ? Text(
                            'Cerrado este día',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          )
                        : SingleChildScrollView(
                            child: DayTimelinePickerWidget(
                              day: _selectedDay,
                              dayOpen: _dayOpen!,
                              dayClose: _dayClose!,
                              durationMinutes: widget.durationMinutes,
                              busyIntervals: _busyIntervals,
                              availableStarts: _availableStarts,
                              selectedStart: _selectedSlot,
                              onStartChanged: (start) {
                                setState(() => _selectedSlot = start);
                              },
                              onValidityChanged: (valid) {
                                if (_slotValid != valid) {
                                  setState(() => _slotValid = valid);
                                }
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PillButtonWidget(
              label: 'Reservar',
              loading: _submitting,
              onPressed: _slotValid && !_submitting ? _onReserve : null,
            ),
          ],
        ),
      ),
    );
  }
}
