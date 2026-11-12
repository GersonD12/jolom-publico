import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jolom/core/providers/hour_format_provider.dart';
import 'package:jolom/core/utils/app_time_format.dart';
import '../utils/availability_time_utils.dart';

/// Resultado del diálogo de nueva ausencia.
class AddAbsenceDialogResult {
  const AddAbsenceDialogResult({
    required this.dayStart,
    required this.dayEnd,
    required this.allDay,
    required this.timeStart,
    required this.timeEnd,
    this.reason,
  });

  /// Primer día inclusive (00:00 local).
  final DateTime dayStart;

  /// Último día inclusive (00:00 local).
  final DateTime dayEnd;
  final bool allDay;
  final TimeOfDay timeStart;
  final TimeOfDay timeEnd;
  final String? reason;
}

/// Muestra el formulario para crear una ausencia.
Future<AddAbsenceDialogResult?> showAddAbsenceDialog(BuildContext context) {
  return showDialog<AddAbsenceDialogResult>(
    context: context,
    builder: (ctx) => const _AddAbsenceDialog(),
  );
}

class _AddAbsenceDialog extends ConsumerStatefulWidget {
  const _AddAbsenceDialog();

  @override
  ConsumerState<_AddAbsenceDialog> createState() => _AddAbsenceDialogState();
}

class _AddAbsenceDialogState extends ConsumerState<_AddAbsenceDialog> {
  late DateTime _dayStart;
  late DateTime _dayEnd;
  var _allDay = true;
  var _timeStart = const TimeOfDay(hour: 12, minute: 0);
  var _timeEnd = const TimeOfDay(hour: 14, minute: 0);
  final _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dayStart = DateTime(now.year, now.month, now.day + 1);
    _dayEnd = _dayStart;
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDay({required bool isStart}) async {
    final initial = isStart ? _dayStart : _dayEnd;
    final first = isStart
        ? DateTime.now().subtract(const Duration(days: 1))
        : _dayStart;
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null) return;
    final next = DateTime(date.year, date.month, date.day);
    setState(() {
      if (isStart) {
        _dayStart = next;
        if (_dayEnd.isBefore(_dayStart)) _dayEnd = _dayStart;
      } else {
        _dayEnd = next;
      }
    });
  }

  Future<void> _pickHour({required bool isStart}) async {
    final initial = isStart ? _timeStart : _timeEnd;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _timeStart = picked;
        if (availabilityTimeToMinutes(_timeEnd) <=
            availabilityTimeToMinutes(_timeStart)) {
          final next = availabilityTimeToMinutes(_timeStart) + 60;
          _timeEnd = TimeOfDay(hour: (next ~/ 60) % 24, minute: next % 60);
        }
      } else if (availabilityTimeToMinutes(picked) >
          availabilityTimeToMinutes(_timeStart)) {
        _timeEnd = picked;
      }
    });
  }

  void _submit() {
    final reason = _reasonCtrl.text.trim();
    Navigator.pop(
      context,
      AddAbsenceDialogResult(
        dayStart: _dayStart,
        dayEnd: _dayEnd,
        allDay: _allDay,
        timeStart: _timeStart,
        timeEnd: _timeEnd,
        reason: reason.isEmpty ? null : reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final use24h = resolveUse24HourFormat(
      context,
      ref.watch(hourFormatProvider),
    );
    String timeLabel(TimeOfDay t) =>
        formatAppTimeOfDay(t, use24HourFormat: use24h);

    return AlertDialog(
      title: const Text('Añadir ausencia'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Desde el día'),
              subtitle: Text(DateFormat.yMMMd().format(_dayStart)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () => _pickDay(isStart: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hasta el día'),
              subtitle: Text(DateFormat.yMMMd().format(_dayEnd)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () => _pickDay(isStart: false),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Todo el día'),
              subtitle: Text(
                _allDay
                    ? 'Cierra el día completo'
                    : 'Solo un rango de horas en esos días',
              ),
              value: _allDay,
              onChanged: (v) => setState(() => _allDay = v),
            ),
            if (!_allDay) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hora inicio'),
                subtitle: Text(timeLabel(_timeStart)),
                trailing: const Icon(Icons.schedule),
                onTap: () => _pickHour(isStart: true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hora fin'),
                subtitle: Text(timeLabel(_timeEnd)),
                trailing: const Icon(Icons.schedule),
                onTap: () => _pickHour(isStart: false),
              ),
            ],
            TextField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
