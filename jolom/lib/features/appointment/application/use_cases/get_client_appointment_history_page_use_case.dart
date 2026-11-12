import '../../domain/entities/appointment_history_cursor_entity.dart';
import '../../domain/entities/appointment_history_page_entity.dart';
import '../../domain/repositories/appointment_repository.dart';

/// Obtiene una página del historial de citas de un cliente.
class GetClientAppointmentHistoryPageUseCase {
  GetClientAppointmentHistoryPageUseCase(this._repository);

  final AppointmentRepository _repository;

  Future<AppointmentHistoryPage> call({
    required String clientId,
    AppointmentHistoryCursor? cursor,
    int limit = 7,
  }) {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Debe ser mayor que cero.');
    }
    return _repository.getClientAppointmentHistoryPage(
      clientId: clientId,
      cursor: cursor,
      limit: limit,
    );
  }
}
