import '../entities/appointment_entity.dart';
import '../entities/appointment_history_cursor_entity.dart';
import '../entities/appointment_history_page_entity.dart';
import '../entities/availability_entity.dart';
import '../entities/busy_interval_entity.dart';
import '../entities/work_calendar_cursor_entity.dart';
import '../entities/work_calendar_page_entity.dart';

/// Contrato de citas y disponibilidad.
abstract class AppointmentRepository {
  Future<Appointment> createAppointment({
    required String salonId,
    required String serviceId,
    required String barberId,
    required DateTime startAt,
    String origin = 'app',
    String? notes,
    String? idempotencyKey,
  });

  Future<Appointment> createManualAppointment({
    required String salonId,
    required String serviceId,
    required String barberId,
    required String clientId,
    required DateTime startAt,
    String? notes,
    String? idempotencyKey,
  });

  Future<void> changeAppointmentStatus({
    required String appointmentId,
    required AppointmentStatus status,
    String? reason,
    String? idempotencyKey,
  });

  /// Franjas ocupadas anónimas + ventana laboral del día.
  Future<DayBusyCanvas> getDayBusyIntervals({
    required String salonId,
    required String barberId,
    required DateTime dayStart,
    required DateTime dayEnd,
    String? serviceId,
  });

  /// Escucha solo las citas activas del cliente.
  Stream<List<Appointment>> watchUpcomingClientAppointments(String clientId);

  /// Obtiene una página puntual del historial, sin mantener un listener.
  Future<AppointmentHistoryPage> getClientAppointmentHistoryPage({
    required String clientId,
    AppointmentHistoryCursor? cursor,
    int limit = 7,
  });

  Stream<List<Appointment>> watchBarberAppointments(String barberId);

  /// Obtiene una página puntual de la agenda, sin mantener un listener global.
  Future<WorkCalendarPage> getBarberAppointmentsPage({
    required String barberId,
    WorkCalendarCursor? cursor,
    int limit = 20,
  });

  Stream<List<Appointment>> watchSalonAppointments(String salonId);

  Future<Availability?> getAvailability(String barberId);

  /// Solo `weeklyHours` del doc padre (sin subcolección exceptions).
  /// Para ficha pública del salón; evita lecturas denegadas de exceptions.
  Future<Map<String, dynamic>?> getAvailabilityWeeklyHours(String barberId);

  /// Observa solo el horario semanal del documento padre, sin excepciones.
  Stream<Map<String, dynamic>?> watchAvailabilityWeeklyHours(String barberId);

  Future<void> setAvailability({
    required String barberId,
    Map<String, dynamic>? weeklyHours,
    String? idempotencyKey,
  });

  /// Crea excepción en `availability/{barberId}/exceptions`.
  /// [type]: `block` | `timeOff`.
  Future<void> createAvailabilityBlock({
    required String barberId,
    required DateTime start,
    required DateTime end,
    String type = 'block',
    String? reason,
    String? idempotencyKey,
  });

  Future<void> deleteAvailabilityException({
    required String barberId,
    required String exceptionId,
    String? idempotencyKey,
  });

  Future<Map<String, dynamic>?> getStats(String scopeId);
}
