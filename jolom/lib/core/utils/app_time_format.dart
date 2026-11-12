import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jolom/core/providers/hour_format_provider.dart';

/// Resuelve si la UI debe mostrar horas en 24h según preferencia y sistema.
bool resolveUse24HourFormat(
  BuildContext context,
  HourFormatPreference preference,
) {
  return switch (preference) {
    HourFormatPreference.h24 => true,
    HourFormatPreference.h12 => false,
    HourFormatPreference.system =>
      MediaQuery.alwaysUse24HourFormatOf(context),
  };
}

/// Patrón de hora para [DateFormat] (`HH:mm` o `h:mm a`).
String appTimePattern({required bool use24HourFormat}) =>
    use24HourFormat ? 'HH:mm' : 'h:mm a';

/// [DateFormat] con fecha fija + hora según preferencia visual.
DateFormat appDateTimeFormat({
  required bool use24HourFormat,
  required String datePattern,
}) {
  return DateFormat('$datePattern ${appTimePattern(use24HourFormat: use24HourFormat)}');
}

/// Formatea un [DateTime] con patrón de fecha + hora visual.
String formatAppDateTime(
  DateTime dateTime, {
  required bool use24HourFormat,
  required String datePattern,
}) {
  return appDateTimeFormat(
    use24HourFormat: use24HourFormat,
    datePattern: datePattern,
  ).format(dateTime);
}

/// Formatea un [TimeOfDay] solo para mostrar (no para persistir en Firestore).
String formatAppTimeOfDay(
  TimeOfDay time, {
  required bool use24HourFormat,
}) {
  final now = DateTime.now();
  final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  return DateFormat(appTimePattern(use24HourFormat: use24HourFormat)).format(dt);
}
