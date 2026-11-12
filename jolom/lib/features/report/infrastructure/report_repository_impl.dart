import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:jolom/core/infrastructure/firestore_date_utils.dart';
import 'package:jolom/features/report/domain/entities/report_entity.dart';
import 'package:jolom/features/report/domain/repositories/report_repository.dart';

/// Implementación de [ReportRepository].
class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Future<bool> getSalonClientBlockStatus({
    required String targetUserId,
    required String sourceAppointmentId,
  }) async {
    final callable = _functions.httpsCallable('getSalonClientBlockStatus');
    final result = await callable.call(<String, dynamic>{
      'targetUserId': targetUserId,
      'sourceAppointmentId': sourceAppointmentId,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['blocked'] as bool? ?? false;
  }

  @override
  Future<bool> setSalonClientBlock({
    required String targetUserId,
    required String sourceAppointmentId,
    required bool blocked,
    String? reason,
    String? idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('setSalonClientBlock');
    final result = await callable.call(<String, dynamic>{
      'targetUserId': targetUserId,
      'sourceAppointmentId': sourceAppointmentId,
      'blocked': blocked,
      'reason': ?reason,
      'idempotencyKey': ?idempotencyKey,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['changed'] as bool? ?? false;
  }

  @override
  Future<Report> submitReport({
    required String targetType,
    required String targetId,
    required String category,
    required String description,
    String? sourceAppointmentId,
    String? idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('submitReport');
    final result = await callable.call(<String, dynamic>{
      'targetType': targetType,
      'targetId': targetId,
      'category': category,
      'description': description,
      'sourceAppointmentId': ?sourceAppointmentId,
      'idempotencyKey': ?idempotencyKey,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final id = data['reportId'] as String;
    final snap = await _db.collection('reports').doc(id).get();
    if (!snap.exists || snap.data() == null) {
      throw StateError('Reporte creado pero no legible: $id');
    }
    final map = snap.data()!;
    return Report.fromMap(
      snap.id,
      map,
      createdAt: requireFirestoreDate(map['createdAt']),
    );
  }

  @override
  Future<List<Report>> listMyReports(String reporterId) async {
    final snap = await _db
        .collection('reports')
        .where('reporterId', isEqualTo: reporterId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      return Report.fromMap(
        d.id,
        data,
        createdAt: requireFirestoreDate(data['createdAt']),
      );
    }).toList();
  }
}
