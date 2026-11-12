/// Posición desde la que continúa la paginación del historial de citas.
class AppointmentHistoryCursor {
  const AppointmentHistoryCursor({
    required this.startAt,
    required this.appointmentId,
  });

  final DateTime startAt;
  final String appointmentId;
}
