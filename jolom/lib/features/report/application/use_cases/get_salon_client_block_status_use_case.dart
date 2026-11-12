import '../../domain/repositories/report_repository.dart';

/// Consulta si un cliente está bloqueado en la peluquería de una cita.
class GetSalonClientBlockStatusUseCase {
  GetSalonClientBlockStatusUseCase(this._repository);

  final ReportRepository _repository;

  Future<bool> call({
    required String targetUserId,
    required String sourceAppointmentId,
  }) {
    return _repository.getSalonClientBlockStatus(
      targetUserId: targetUserId,
      sourceAppointmentId: sourceAppointmentId,
    );
  }
}
