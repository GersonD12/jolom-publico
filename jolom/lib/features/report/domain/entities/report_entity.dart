/// Estado público mínimo de un reporte.
enum ReportStatus { received, inReview, closedWithAction, closedWithoutAction }

/// Denuncia privada.
class Report {
  const Report({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String reporterId;
  final String targetType;
  final String targetId;
  final String category;
  final String description;
  final ReportStatus status;
  final DateTime createdAt;

  factory Report.fromMap(
    String id,
    Map<String, dynamic> map, {
    required DateTime createdAt,
  }) {
    return Report(
      id: id,
      reporterId: map['reporterId'] as String? ?? '',
      targetType: map['targetType'] as String? ?? '',
      targetId: map['targetId'] as String? ?? '',
      category: map['category'] as String? ?? '',
      description: map['description'] as String? ?? '',
      status: ReportStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ReportStatus.received,
      ),
      createdAt: createdAt,
    );
  }
}
