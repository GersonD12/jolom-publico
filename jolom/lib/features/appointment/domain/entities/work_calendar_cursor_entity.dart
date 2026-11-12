/// Posición desde la que continúa la paginación de la agenda de trabajo.
class WorkCalendarCursor {
  const WorkCalendarCursor({
    required this.startAt,
    required this.appointmentId,
  });

  final DateTime startAt;
  final String appointmentId;
}
