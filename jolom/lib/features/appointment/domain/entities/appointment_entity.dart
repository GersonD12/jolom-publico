/// Estado de una cita (PRD §5.1).
enum AppointmentStatus {
  pending,
  confirmed,
  rejected,
  cancelledByClient,
  cancelledByBusiness,
  completed,
  noShow,
}

/// Etiqueta en español para UI (el valor en Firestore sigue en inglés).
extension AppointmentStatusLabel on AppointmentStatus {
  String get labelEs => switch (this) {
    AppointmentStatus.pending => 'Pendiente',
    AppointmentStatus.confirmed => 'Confirmada',
    AppointmentStatus.rejected => 'Rechazada',
    AppointmentStatus.cancelledByClient => 'Cancelada por el cliente',
    AppointmentStatus.cancelledByBusiness => 'Cancelada por el negocio',
    AppointmentStatus.completed => 'Finalizada',
    AppointmentStatus.noShow => 'No asistió',
  };
}

/// Origen de la cita.
enum AppointmentOrigin { app, qr, manual }

/// Cita / reserva.
class Appointment {
  const Appointment({
    required this.id,
    required this.salonId,
    required this.clientId,
    required this.barberId,
    required this.serviceId,
    required this.serviceName,
    required this.servicePrice,
    required this.serviceCurrency,
    required this.durationMinutes,
    required this.startAt,
    required this.endAt,
    required this.timeZone,
    required this.status,
    required this.origin,
    this.notes,
  });

  final String id;
  final String salonId;
  final String clientId;
  final String barberId;
  final String serviceId;
  final String serviceName;
  final double servicePrice;
  final String serviceCurrency;
  final int durationMinutes;
  final DateTime startAt;
  final DateTime endAt;
  final String timeZone;
  final AppointmentStatus status;
  final AppointmentOrigin origin;
  final String? notes;

  factory Appointment.fromMap(
    String id,
    Map<String, dynamic> map, {
    required DateTime startAt,
    required DateTime endAt,
  }) {
    return Appointment(
      id: id,
      salonId: map['salonId'] as String? ?? '',
      clientId: map['clientId'] as String? ?? '',
      barberId: map['barberId'] as String? ?? '',
      serviceId: map['serviceId'] as String? ?? '',
      serviceName: map['serviceName'] as String? ?? '',
      servicePrice: (map['servicePrice'] as num?)?.toDouble() ?? 0,
      serviceCurrency: map['serviceCurrency'] as String? ?? 'GTQ',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
      startAt: startAt,
      endAt: endAt,
      timeZone: map['timeZone'] as String? ?? 'America/Guatemala',
      status: AppointmentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AppointmentStatus.pending,
      ),
      origin: AppointmentOrigin.values.firstWhere(
        (e) => e.name == map['origin'],
        orElse: () => AppointmentOrigin.app,
      ),
      notes: map['notes'] as String?,
    );
  }
}
