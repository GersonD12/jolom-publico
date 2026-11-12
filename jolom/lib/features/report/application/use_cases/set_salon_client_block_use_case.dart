import '../../domain/repositories/report_repository.dart';

/// Bloquea o desbloquea al cliente solo en la peluquería de una cita.
class SetSalonClientBlockUseCase {
  SetSalonClientBlockUseCase(this._repository);

  final ReportRepository _repository;

  Future<bool> call({
    required String targetUserId,
    required String sourceAppointmentId,
    required bool blocked,
    String? reason,
    String? idempotencyKey,
  }) {
    return _repository.setSalonClientBlock(
      targetUserId: targetUserId,
      sourceAppointmentId: sourceAppointmentId,
      blocked: blocked,
      reason: reason,
      idempotencyKey: idempotencyKey,
    );
  }
}
