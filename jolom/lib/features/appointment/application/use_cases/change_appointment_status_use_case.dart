import '../../domain/entities/appointment_entity.dart';
import '../../domain/repositories/appointment_repository.dart';

/// Cambia el estado de una cita.
class ChangeAppointmentStatusUseCase {
  ChangeAppointmentStatusUseCase(this._repository);

  final AppointmentRepository _repository;

  Future<void> call({
    required String appointmentId,
    required AppointmentStatus status,
    String? reason,
    String? idempotencyKey,
  }) {
    return _repository.changeAppointmentStatus(
      appointmentId: appointmentId,
      status: status,
      reason: reason,
      idempotencyKey: idempotencyKey,
    );
  }
}
