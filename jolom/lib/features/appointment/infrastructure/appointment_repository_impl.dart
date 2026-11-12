import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:jolom/core/infrastructure/firestore_date_utils.dart';
import 'package:jolom/features/appointment/domain/entities/appointment_entity.dart';
import 'package:jolom/features/appointment/domain/entities/appointment_history_cursor_entity.dart';
import 'package:jolom/features/appointment/domain/entities/appointment_history_page_entity.dart';
import 'package:jolom/features/appointment/domain/entities/availability_entity.dart';
import 'package:jolom/features/appointment/domain/entities/busy_interval_entity.dart';
import 'package:jolom/features/appointment/domain/entities/work_calendar_cursor_entity.dart';
import 'package:jolom/features/appointment/domain/entities/work_calendar_page_entity.dart';
import 'package:jolom/features/appointment/domain/repositories/appointment_repository.dart';

/// Implementación de [AppointmentRepository].
class AppointmentRepositoryImpl implements AppointmentRepository {
  AppointmentRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final Map<String, _DayBusyCacheEntry> _dayBusyCache = {};
  final Map<String, Future<DayBusyCanvas>> _dayBusyInFlight = {};
  int _dayBusyCacheRevision = 0;

  static const _dayBusyCacheTtl = Duration(seconds: 30);

  static const _upcomingStatuses = ['pending', 'confirmed'];
  static const _historyStatuses = [
    'rejected',
    'cancelledByClient',
    'cancelledByBusiness',
    'completed',
    'noShow',
  ];

  void _invalidateDayBusyCache() {
    _dayBusyCacheRevision++;
    _dayBusyCache.clear();
  }

  Appointment _mapDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Appointment.fromMap(
      doc.id,
      data,
      startAt: requireFirestoreDate(data['startAt']),
      endAt: requireFirestoreDate(data['endAt']),
    );
  }

  @override
  Future<Appointment> createAppointment({
    required String salonId,
    required String serviceId,
    required String barberId,
    required DateTime startAt,
    String origin = 'app',
    String? notes,
    String? idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('createAppointment');
    final result = await callable.call(<String, dynamic>{
      'salonId': salonId,
      'serviceId': serviceId,
      'barberId': barberId,
      'startAt': startAt.toUtc().toIso8601String(),
      'dayStart': DateTime(
        startAt.year,
        startAt.month,
        startAt.day,
      ).toUtc().toIso8601String(),
      'dayEnd': DateTime(
        startAt.year,
        startAt.month,
        startAt.day + 1,
      ).toUtc().toIso8601String(),
      'origin': origin,
      'notes': ?notes,
      'idempotencyKey': ?idempotencyKey,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final id = data['appointmentId'] as String;
    _invalidateDayBusyCache();
    final snap = await _db.collection('appointments').doc(id).get();
    if (!snap.exists || snap.data() == null) {
      throw StateError('Cita creada pero no legible: $id');
    }
    return _mapDoc(snap);
  }

  @override
  Future<Appointment> createManualAppointment({
    required String salonId,
    required String serviceId,
    required String barberId,
    required String clientId,
    required DateTime startAt,
    String? notes,
    String? idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('createManualAppointment');
    final result = await callable.call(<String, dynamic>{
      'salonId': salonId,
      'serviceId': serviceId,
      'barberId': barberId,
      'clientId': clientId,
      'startAt': startAt.toUtc().toIso8601String(),
      'notes': ?notes,
      'idempotencyKey': ?idempotencyKey,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final id = data['appointmentId'] as String;
    _invalidateDayBusyCache();
    final snap = await _db.collection('appointments').doc(id).get();
    if (!snap.exists || snap.data() == null) {
      throw StateError('Cita manual creada pero no legible: $id');
    }
    return _mapDoc(snap);
  }

  @override
  Future<void> changeAppointmentStatus({
    required String appointmentId,
    required AppointmentStatus status,
    String? reason,
    String? idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('changeAppointmentStatus');
    await callable.call(<String, dynamic>{
      'appointmentId': appointmentId,
      'status': status.name,
      'reason': ?reason,
      'idempotencyKey': ?idempotencyKey,
    });
    _invalidateDayBusyCache();
  }

  @override
  Future<DayBusyCanvas> getDayBusyIntervals({
    required String salonId,
    required String barberId,
    required DateTime dayStart,
    required DateTime dayEnd,
    String? serviceId,
  }) {
    final cacheKey = [
      salonId,
      serviceId ?? '',
      barberId,
      dayStart.toUtc().toIso8601String(),
    ].join('|');
    final cached = _dayBusyCache[cacheKey];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return Future.value(cached.canvas);
    }

    final inFlight = _dayBusyInFlight[cacheKey];
    if (inFlight != null) return inFlight;

    final cacheRevision = _dayBusyCacheRevision;
    final request = _fetchDayBusyIntervals(
      salonId: salonId,
      barberId: barberId,
      dayStart: dayStart,
      dayEnd: dayEnd,
      serviceId: serviceId,
    );
    _dayBusyInFlight[cacheKey] = request;
    return request
        .then((canvas) {
          if (cacheRevision == _dayBusyCacheRevision) {
            _dayBusyCache[cacheKey] = _DayBusyCacheEntry(
              canvas: canvas,
              expiresAt: DateTime.now().add(_dayBusyCacheTtl),
            );
          }
          return canvas;
        })
        .whenComplete(() => _dayBusyInFlight.remove(cacheKey));
  }

  Future<DayBusyCanvas> _fetchDayBusyIntervals({
    required String salonId,
    required String barberId,
    required DateTime dayStart,
    required DateTime dayEnd,
    String? serviceId,
  }) async {
    final callable = _functions.httpsCallable('getDayBusyIntervals');
    final result = await callable.call(<String, dynamic>{
      'salonId': salonId,
      'barberId': barberId,
      'dayStart': dayStart.toUtc().toIso8601String(),
      'dayEnd': dayEnd.toUtc().toIso8601String(),
      'serviceId': ?serviceId,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final raw = data['intervals'];
    final intervals = <BusyInterval>[];
    if (raw is List) {
      for (final item in raw) {
        final m = Map<String, dynamic>.from(item as Map);
        intervals.add(
          BusyInterval(
            start: DateTime.parse(m['start'] as String).toLocal(),
            end: DateTime.parse(m['end'] as String).toLocal(),
          ),
        );
      }
    }

    Set<DateTime>? availableStarts;
    final rawAvailableStarts = data['availableStarts'];
    if (rawAvailableStarts is List) {
      availableStarts = {};
      for (final item in rawAvailableStarts) {
        if (item is String) {
          availableStarts.add(DateTime.parse(item).toLocal());
        }
      }
    }

    final isClosed = data['isClosed'] == true;
    final openMins = _parseHmToMinutes(data['dayOpen']);
    final closeMins = _parseHmToMinutes(data['dayClose']);
    final closed =
        isClosed ||
        openMins == null ||
        closeMins == null ||
        closeMins <= openMins;

    return DayBusyCanvas(
      intervals: intervals,
      isClosed: closed,
      dayOpenMinutes: closed ? null : openMins,
      dayCloseMinutes: closed ? null : closeMins,
      availableStarts: availableStarts,
    );
  }

  /// Parsea "HH:mm" a minutos desde medianoche.
  int? _parseHmToMinutes(Object? raw) {
    if (raw is! String) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  @override
  Stream<List<Appointment>> watchUpcomingClientAppointments(String clientId) {
    return _db
        .collection('appointments')
        .where('clientId', isEqualTo: clientId)
        .where('status', whereIn: _upcomingStatuses)
        .orderBy('startAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_mapDoc).toList());
  }

  @override
  Future<AppointmentHistoryPage> getClientAppointmentHistoryPage({
    required String clientId,
    AppointmentHistoryCursor? cursor,
    int limit = 7,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection('appointments')
        .where('clientId', isEqualTo: clientId)
        .where('status', whereIn: _historyStatuses)
        .orderBy('startAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit);

    if (cursor != null) {
      query = query.startAfter([
        Timestamp.fromDate(cursor.startAt),
        cursor.appointmentId,
      ]);
    }

    final snap = await query.get();
    final items = snap.docs.map(_mapDoc).toList();
    final hasMore = snap.docs.length == limit;
    final lastDoc = snap.docs.lastOrNull;

    return AppointmentHistoryPage(
      items: items,
      hasMore: hasMore,
      nextCursor: hasMore && lastDoc != null
          ? AppointmentHistoryCursor(
              startAt: requireFirestoreDate(lastDoc.data()['startAt']),
              appointmentId: lastDoc.id,
            )
          : null,
    );
  }

  @override
  Stream<List<Appointment>> watchBarberAppointments(String barberId) {
    return _db
        .collection('appointments')
        .where('barberId', isEqualTo: barberId)
        .orderBy('startAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_mapDoc).toList());
  }

  @override
  Future<WorkCalendarPage> getBarberAppointmentsPage({
    required String barberId,
    WorkCalendarCursor? cursor,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection('appointments')
        .where('barberId', isEqualTo: barberId)
        .orderBy('startAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit + 1);

    if (cursor != null) {
      query = query.startAfter([
        Timestamp.fromDate(cursor.startAt),
        cursor.appointmentId,
      ]);
    }

    final snap = await query.get();
    final pageDocs = snap.docs.take(limit).toList();
    final lastDoc = pageDocs.lastOrNull;
    return WorkCalendarPage(
      items: pageDocs.map(_mapDoc).toList(),
      hasMore: snap.docs.length > limit,
      nextCursor: lastDoc == null
          ? null
          : WorkCalendarCursor(
              startAt: requireFirestoreDate(lastDoc.data()['startAt']),
              appointmentId: lastDoc.id,
            ),
    );
  }

  @override
  Stream<List<Appointment>> watchSalonAppointments(String salonId) {
    return _db
        .collection('appointments')
        .where('salonId', isEqualTo: salonId)
        .orderBy('startAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_mapDoc).toList());
  }

  @override
  Future<Availability?> getAvailability(String barberId) async {
    final snap = await _db.collection('availability').doc(barberId).get();
    if (!snap.exists || snap.data() == null) return null;
    final data = Map<String, dynamic>.from(snap.data()!);

    final exceptionsSnap = await _db
        .collection('availability')
        .doc(barberId)
        .collection('exceptions')
        .orderBy('start')
        .get();
    final exceptions = exceptionsSnap.docs.map((doc) {
      final m = Map<String, dynamic>.from(doc.data());
      m['start'] = parseFirestoreDate(m['start']) ?? m['start'];
      m['end'] = parseFirestoreDate(m['end']) ?? m['end'];
      return AvailabilityException.fromMap(doc.id, m);
    }).toList();

    return Availability.fromMap(barberId, data, exceptions: exceptions);
  }

  @override
  Future<Map<String, dynamic>?> getAvailabilityWeeklyHours(
    String barberId,
  ) async {
    final snap = await _db.collection('availability').doc(barberId).get();
    if (!snap.exists || snap.data() == null) return null;
    final data = snap.data()!;
    final raw = data['weeklyHours'];
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  @override
  Stream<Map<String, dynamic>?> watchAvailabilityWeeklyHours(String barberId) {
    return _db.collection('availability').doc(barberId).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      final raw = data['weeklyHours'];
      if (raw is! Map) return null;
      return Map<String, dynamic>.from(raw);
    });
  }

  @override
  Future<void> setAvailability({
    required String barberId,
    Map<String, dynamic>? weeklyHours,
    String? idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('setAvailability');
    await callable.call(<String, dynamic>{
      'barberId': barberId,
      'weeklyHours': ?weeklyHours,
      'idempotencyKey': ?idempotencyKey,
    });
    _invalidateDayBusyCache();
  }

  @override
  Future<void> createAvailabilityBlock({
    required String barberId,
    required DateTime start,
    required DateTime end,
    String type = 'block',
    String? reason,
    String? idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('createAvailabilityBlock');
    await callable.call(<String, dynamic>{
      'barberId': barberId,
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
      'type': type,
      'reason': ?reason,
      'idempotencyKey': ?idempotencyKey,
    });
    _invalidateDayBusyCache();
  }

  @override
  Future<void> deleteAvailabilityException({
    required String barberId,
    required String exceptionId,
    String? idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('deleteAvailabilityException');
    await callable.call(<String, dynamic>{
      'barberId': barberId,
      'exceptionId': exceptionId,
      'idempotencyKey': ?idempotencyKey,
    });
    _invalidateDayBusyCache();
  }

  @override
  Future<Map<String, dynamic>?> getStats(String scopeId) async {
    final snap = await _db.collection('stats').doc(scopeId).get();
    if (!snap.exists || snap.data() == null) return null;
    return Map<String, dynamic>.from(snap.data()!);
  }
}

class _DayBusyCacheEntry {
  const _DayBusyCacheEntry({required this.canvas, required this.expiresAt});

  final DayBusyCanvas canvas;
  final DateTime expiresAt;
}
