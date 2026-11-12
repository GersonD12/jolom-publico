import '../../domain/entities/appointment_entity.dart';
import '../../domain/repositories/appointment_repository.dart';

/// Crea una cita vía Cloud Function.
class CreateAppointmentUseCase {
  CreateAppointmentUseCase(this._repository);

  final AppointmentRepository _repository;

  Future<Appointment> call({
    required String salonId,
    required String serviceId,
    required String barberId,
    required DateTime startAt,
    String origin = 'app',
    String? notes,
    String? idempotencyKey,
  }) {
    return _repository.createAppointment(
      salonId: salonId,
      serviceId: serviceId,
      barberId: barberId,
      startAt: startAt,
      origin: origin,
      notes: notes,
      idempotencyKey: idempotencyKey,
    );
  }
}
