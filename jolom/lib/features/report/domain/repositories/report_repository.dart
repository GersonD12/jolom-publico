import '../entities/report_entity.dart';

/// Contrato de reportes / denuncias.
abstract class ReportRepository {
  Future<bool> getSalonClientBlockStatus({
    required String targetUserId,
    required String sourceAppointmentId,
  });

  Future<bool> setSalonClientBlock({
    required String targetUserId,
    required String sourceAppointmentId,
    required bool blocked,
    String? reason,
    String? idempotencyKey,
  });

  Future<Report> submitReport({
    required String targetType,
    required String targetId,
    required String category,
    required String description,
    String? sourceAppointmentId,
    String? idempotencyKey,
  });

  Future<List<Report>> listMyReports(String reporterId);
}
