/// Disponibilidad semanal y excepciones de un peluquero.
class Availability {
  const Availability({
    required this.userId,
    required this.salonId,
    this.weeklyHours = const {},
    this.exceptions = const [],
  });

  final String userId;
  final String salonId;
  final Map<String, dynamic> weeklyHours;
  final List<AvailabilityException> exceptions;

  factory Availability.fromMap(
    String userId,
    Map<String, dynamic> map, {
    List<AvailabilityException> exceptions = const [],
  }) {
    return Availability(
      userId: userId,
      salonId: map['salonId'] as String? ?? '',
      weeklyHours: map['weeklyHours'] is Map
          ? Map<String, dynamic>.from(map['weeklyHours'] as Map)
          : const {},
      exceptions: exceptions,
    );
  }
}

/// Indica si el horario semanal contiene al menos un día abierto válido.
bool hasAnyOpenAvailabilityDay(Map<String, dynamic>? weeklyHours) {
  if (weeklyHours == null || weeklyHours.isEmpty) return false;
  return weeklyHours.values.any((raw) {
    if (raw is! Map) return false;
    final start = raw['start'];
    final end = raw['end'];
    return start is String &&
        start.trim().isNotEmpty &&
        end is String &&
        end.trim().isNotEmpty;
  });
}

/// Excepción puntual o ausencia (vacaciones).
class AvailabilityException {
  const AvailabilityException({
    required this.id,
    required this.type,
    required this.startAt,
    required this.endAt,
    this.reason,
    this.createdBy,
  });

  final String id;

  /// `block` | `timeOff`
  final String type;
  final DateTime startAt;
  final DateTime endAt;
  final String? reason;
  final String? createdBy;

  bool get isTimeOff => type == 'timeOff';

  factory AvailabilityException.fromMap(String id, Map<String, dynamic> map) {
    DateTime parse(Object? value) {
      if (value is DateTime) return value;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return AvailabilityException(
      id: id,
      type: map['type'] as String? ?? 'block',
      startAt: parse(map['start']),
      endAt: parse(map['end']),
      reason: map['reason'] as String?,
      createdBy: map['createdBy'] as String?,
    );
  }
}
