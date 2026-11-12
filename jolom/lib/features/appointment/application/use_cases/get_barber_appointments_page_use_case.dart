import '../../domain/entities/work_calendar_cursor_entity.dart';
import '../../domain/entities/work_calendar_page_entity.dart';
import '../../domain/repositories/appointment_repository.dart';

/// Obtiene una página ordenada de la agenda del peluquero autenticado.
class GetBarberAppointmentsPageUseCase {
  GetBarberAppointmentsPageUseCase(this._repository);

  final AppointmentRepository _repository;

  Future<WorkCalendarPage> call({
    required String barberId,
    WorkCalendarCursor? cursor,
    int limit = 20,
  }) {
    if (barberId.isEmpty) {
      throw ArgumentError.value(barberId, 'barberId', 'No puede estar vacío.');
    }
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Debe ser mayor que cero.');
    }
    return _repository.getBarberAppointmentsPage(
      barberId: barberId,
      cursor: cursor,
      limit: limit,
    );
  }
}
