import 'package:flutter/material.dart';

/// Helpers de horas HH:mm para la UI de disponibilidad.
String formatAvailabilityHm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay? parseAvailabilityHm(Object? raw) {
  if (raw is! String) return null;
  final parts = raw.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return TimeOfDay(hour: h, minute: m);
}

int availabilityTimeToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

/// Claves de día semanal alineadas a Firestore `weeklyHours`.
const availabilityWeekDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

const availabilityWeekDayLabels = {
  'mon': 'Lunes',
  'tue': 'Martes',
  'wed': 'Miércoles',
  'thu': 'Jueves',
  'fri': 'Viernes',
  'sat': 'Sábado',
  'sun': 'Domingo',
};
