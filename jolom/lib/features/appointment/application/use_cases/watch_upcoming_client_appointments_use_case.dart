import '../../domain/entities/appointment_entity.dart';
import '../../domain/repositories/appointment_repository.dart';

/// Escucha las citas pendientes o confirmadas de un cliente.
class WatchUpcomingClientAppointmentsUseCase {
  WatchUpcomingClientAppointmentsUseCase(this._repository);

  final AppointmentRepository _repository;

  Stream<List<Appointment>> call(String clientId) {
    return _repository.watchUpcomingClientAppointments(clientId);
  }
}
