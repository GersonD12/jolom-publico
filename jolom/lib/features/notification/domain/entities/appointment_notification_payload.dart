import 'dart:convert';

import 'package:jolom/features/appointment/domain/entities/appointment_entity.dart';

/// Destino explícito de una notificación de cita.
enum AppointmentNotificationOpenMode { client, work }

/// Evento que originó una notificación de cita.
enum AppointmentNotificationKind {
  request,
  statusChange,
  reminder,
  manual,
  accountDeletion,
}

/// Payload estándar de navegación para notificaciones de citas.
class AppointmentNotificationPayload {
  const AppointmentNotificationPayload({
    required this.appointmentId,
    required this.openMode,
    required this.kind,
    this.status,
  });

  static const type = 'appointment';

  final String appointmentId;
  final AppointmentNotificationOpenMode openMode;
  final AppointmentNotificationKind kind;
  final AppointmentStatus? status;

  Map<String, String> toData() => {
    'type': type,
    'appointmentId': appointmentId,
    'openMode': openMode.name,
    'kind': kind.name,
    if (status != null) 'status': status!.name,
  };

  String toLocalNotificationPayload() => jsonEncode(toData());

  static AppointmentNotificationPayload? tryParse(Map<String, dynamic> data) {
    if (data['type'] != type) return null;

    final appointmentId = data['appointmentId'];
    final rawOpenMode = data['openMode'];
    final rawKind = data['kind'];
    if (appointmentId is! String || appointmentId.isEmpty) return null;
    if (rawOpenMode is! String || rawKind is! String) return null;

    final openMode = AppointmentNotificationOpenMode.values
        .where((value) => value.name == rawOpenMode)
        .firstOrNull;
    final kind = AppointmentNotificationKind.values
        .where((value) => value.name == rawKind)
        .firstOrNull;
    if (openMode == null || kind == null) return null;

    AppointmentStatus? status;
    final rawStatus = data['status'];
    if (rawStatus != null) {
      if (rawStatus is! String) return null;
      status = AppointmentStatus.values
          .where((value) => value.name == rawStatus)
          .firstOrNull;
      if (status == null) return null;
    }

    return AppointmentNotificationPayload(
      appointmentId: appointmentId,
      openMode: openMode,
      kind: kind,
      status: status,
    );
  }

  static AppointmentNotificationPayload? tryParseLocalNotificationPayload(
    String? payload,
  ) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      return tryParse(Map<String, dynamic>.from(decoded));
    } on FormatException {
      return null;
    }
  }
}
