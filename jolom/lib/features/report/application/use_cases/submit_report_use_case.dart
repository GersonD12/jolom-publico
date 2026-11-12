import '../../domain/entities/report_entity.dart';
import '../../domain/repositories/report_repository.dart';

/// Envía un reporte vía Cloud Function.
class SubmitReportUseCase {
  SubmitReportUseCase(this._repository);

  final ReportRepository _repository;

  Future<Report> call({
    required String targetType,
    required String targetId,
    required String category,
    required String description,
    String? sourceAppointmentId,
    String? idempotencyKey,
  }) {
    return _repository.submitReport(
      targetType: targetType,
      targetId: targetId,
      category: category,
      description: description,
      sourceAppointmentId: sourceAppointmentId,
      idempotencyKey: idempotencyKey,
    );
  }
}
