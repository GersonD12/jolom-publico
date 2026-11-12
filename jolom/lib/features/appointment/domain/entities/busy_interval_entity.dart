/// Intervalo ocupado anónimo (sin PII) para el lienzo de reserva.
class BusyInterval {
  const BusyInterval({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool overlaps(DateTime rangeStart, DateTime rangeEnd) =>
      rangeStart.isBefore(end) && rangeEnd.isAfter(start);
}

/// Respuesta del lienzo de un día: ocupación + ventana laboral.
class DayBusyCanvas {
  const DayBusyCanvas({
    required this.intervals,
    required this.isClosed,
    this.dayOpenMinutes,
    this.dayCloseMinutes,
    this.availableStarts,
  });

  final List<BusyInterval> intervals;
  final bool isClosed;

  /// Minutos desde medianoche (apertura). Null si [isClosed].
  final int? dayOpenMinutes;

  /// Minutos desde medianoche (cierre). Null si [isClosed].
  final int? dayCloseMinutes;

  /// Inicios válidos calculados cuando se eligió "Cualquiera".
  /// Null cuando la consulta corresponde a un peluquero específico.
  final Set<DateTime>? availableStarts;
}
