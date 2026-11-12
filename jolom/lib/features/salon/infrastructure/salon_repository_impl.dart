import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:jolom/core/infrastructure/firestore_date_utils.dart';
import 'package:jolom/features/salon/domain/entities/salon_entity.dart';
import 'package:jolom/features/salon/domain/entities/nearby_salon_entity.dart';
import 'package:jolom/features/salon/domain/entities/salon_invitation_entity.dart';
import 'package:jolom/features/salon/domain/entities/salon_membership_entity.dart';
import 'package:jolom/features/salon/domain/entities/service_entity.dart';
import 'package:jolom/features/salon/domain/repositories/salon_repository.dart';

import 'geohash_query_bounds.dart';

/// Implementación de [SalonRepository] (Firestore + callables).
class SalonRepositoryImpl implements SalonRepository {
  SalonRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Future<Salon> createSalon({
    required String name,
    String? description,
    String? contactPhone,
    String? address,
    String? idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('createSalon');
    final result = await callable.call(<String, dynamic>{
      'name': name,
      'description': ?description,
      'contactPhone': ?contactPhone,
      'address': ?address,
      'idempotencyKey': ?idempotencyKey,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final salonId = data['salonId'] as String;
    final salon = await getSalon(salonId);
    if (salon == null) {
      throw StateError('Peluquería creada pero no legible: $salonId');
    }
    return salon;
  }

  @override
  Future<void> updateSalon({
    required String salonId,
    String? name,
    String? description,
    String? contactPhone,
    String? address,
    String? city,
    double? latitude,
    double? longitude,
    String? coverImageUrl,
    List<String>? imageUrls,
    Map<String, dynamic>? businessHours,
    String? idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('updateSalon');
    final hasLocation = latitude != null && longitude != null;
    await callable.call(<String, dynamic>{
      'salonId': salonId,
      'name': ?name,
      'description': ?description,
      'contactPhone': ?contactPhone,
      'address': ?address,
      'city': ?city,
      if (hasLocation)
        'location': {'latitude': latitude, 'longitude': longitude},
      'coverImageUrl': ?coverImageUrl,
      'imageUrls': ?imageUrls,
      'businessHours': ?businessHours,
      'idempotencyKey': ?idempotencyKey,
    });
  }

  @override
  Future<void> setSalonPublishStatus({
    required String salonId,
    required SalonPublishStatus publishStatus,
    String? idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('setSalonPublishStatus');
    await callable.call(<String, dynamic>{
      'salonId': salonId,
      'publishStatus': publishStatus.name,
      'idempotencyKey': ?idempotencyKey,
    });
  }

  @override
  Future<Salon?> getSalon(String salonId) async {
    final snap = await _db.collection('salons').doc(salonId).get();
    if (!snap.exists || snap.data() == null) return null;
    return Salon.fromMap(snap.id, snap.data()!);
  }

  @override
  Stream<List<Salon>> watchPublishedSalons({int limit = 50}) {
    return _db
        .collection('salons')
        .where('publishStatus', isEqualTo: 'published')
        .where('isDeleted', isEqualTo: false)
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Salon.fromMap(d.id, d.data())).toList(),
        );
  }

  @override
  Future<List<NearbySalon>> listPublishedSalonsNearby(
    SalonSearchArea area,
  ) async {
    final bounds = GeohashQueryBounds.forArea(area);
    final snapshots = await Future.wait(
      bounds.map(
        (bound) => _db
            .collection('salons')
            .where('publishStatus', isEqualTo: 'published')
            .where('isDeleted', isEqualTo: false)
            .orderBy('geohash')
            .startAt([bound.start])
            .endAt([bound.end])
            .get(),
      ),
    );

    final documents = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final snapshot in snapshots) {
      for (final document in snapshot.docs) {
        documents[document.id] = document;
      }
    }

    final nearby = <NearbySalon>[];
    for (final document in documents.values) {
      final salon = Salon.fromMap(document.id, document.data());
      final latitude = salon.latitude;
      final longitude = salon.longitude;
      if (latitude == null || longitude == null) continue;
      final distanceKm = GeohashQueryBounds.distanceKm(
        area.center,
        GeoCoordinates(latitude: latitude, longitude: longitude),
      );
      if (distanceKm <= area.radiusKm) {
        nearby.add(NearbySalon(salon: salon, distanceKm: distanceKm));
      }
    }
    nearby.sort((left, right) => left.distanceKm.compareTo(right.distanceKm));
    return nearby;
  }

  @override
  Future<List<Service>> listServices(
    String salonId, {
    bool includeInactive = false,
  }) async {
    // Debe alinear con firestore.rules (isDeleted + status) o la query
    // completa falla con permission-denied para lectores públicos.
    Query<Map<String, dynamic>> query = _db
        .collection('services')
        .where('salonId', isEqualTo: salonId)
        .where('isDeleted', isEqualTo: false);
    if (!includeInactive) {
      query = query.where('status', isEqualTo: 'active');
    }
    final snap = await query.get();
    return snap.docs.map((d) => Service.fromMap(d.id, d.data())).toList();
  }

  @override
  Future<String> createService({
    required String salonId,
    required String name,
    required int durationMinutes,
    required double price,
    String? description,
    List<String>? enabledBarberIds,
    String? idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('createService');
    final result = await callable.call(<String, dynamic>{
      'salonId': salonId,
      'name': name,
      'durationMinutes': durationMinutes,
      'price': price,
      'description': ?description,
      'enabledBarberIds': ?enabledBarberIds,
      'idempotencyKey': ?idempotencyKey,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['serviceId'] as String;
  }

  @override
  Future<void> updateService({
    required String serviceId,
    String? name,
    String? description,
    int? durationMinutes,
    double? price,
    List<String>? enabledBarberIds,
    String? status,
    bool? isDeleted,
    String? idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('updateService');
    await callable.call(<String, dynamic>{
      'serviceId': serviceId,
      'name': ?name,
      'description': ?description,
      'durationMinutes': ?durationMinutes,
      'price': ?price,
      'enabledBarberIds': ?enabledBarberIds,
      'status': ?status,
      'isDeleted': ?isDeleted,
      'idempotencyKey': ?idempotencyKey,
    });
  }

  @override
  Future<SalonMembership?> getMembership(String userId) async {
    final snap = await _db.collection('salonMemberships').doc(userId).get();
    if (!snap.exists || snap.data() == null) return null;
    return SalonMembership.fromMap(snap.id, snap.data()!);
  }

  @override
  Stream<SalonMembership?> watchMembership(String userId) {
    return _db.collection('salonMemberships').doc(userId).snapshots().map((
      snap,
    ) {
      if (!snap.exists || snap.data() == null) return null;
      return SalonMembership.fromMap(snap.id, snap.data()!);
    });
  }

  @override
  Future<List<SalonMembership>> listSalonMembers(
    String salonId, {
    bool includePendingExit = false,
  }) async {
    // Solo `active` alinea con rules públicas de reserva; `pendingExit`
    // requiere owner (team) — whereIn rompería guest/cliente.
    Query<Map<String, dynamic>> query = _db
        .collection('salonMemberships')
        .where('salonId', isEqualTo: salonId);
    if (includePendingExit) {
      query = query.where('status', whereIn: ['active', 'pendingExit']);
    } else {
      query = query.where('status', isEqualTo: 'active');
    }
    final snap = await query.get();
    return snap.docs
        .map((d) => SalonMembership.fromMap(d.id, d.data()))
        .toList();
  }

  @override
  Future<String> inviteBarber({
    required String salonId,
    required String inviteeEmail,
    String? idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('inviteBarber');
    final result = await callable.call(<String, dynamic>{
      'salonId': salonId,
      'inviteeEmail': inviteeEmail.trim().toLowerCase(),
      'idempotencyKey': ?idempotencyKey,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['invitationId'] as String;
  }

  @override
  Future<void> respondToInvitation({
    required String invitationId,
    required bool accept,
    String? idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('respondToInvitation');
    await callable.call(<String, dynamic>{
      'invitationId': invitationId,
      'accept': accept,
      'idempotencyKey': ?idempotencyKey,
    });
  }

  @override
  Future<List<SalonInvitation>> listPendingInvitationsForUser(
    String userId,
  ) async {
    final snap = await _db
        .collection('salonInvitations')
        .where('inviteeId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      return SalonInvitation.fromMap(
        d.id,
        data,
        expiresAt: requireFirestoreDate(data['expiresAt']),
      );
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> beginMembershipExit({
    String? targetUserId,
    String? idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('beginMembershipExit');
    final result = await callable.call(<String, dynamic>{
      'targetUserId': ?targetUserId,
      'idempotencyKey': ?idempotencyKey,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  Future<void> completeMembershipExit({
    String? targetUserId,
    String? idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('completeMembershipExit');
    await callable.call(<String, dynamic>{
      'targetUserId': ?targetUserId,
      'idempotencyKey': ?idempotencyKey,
    });
  }

  @override
  Future<void> recordQrOpen(String salonId) async {
    final callable = _functions.httpsCallable('recordQrOpen');
    await callable.call(<String, dynamic>{'salonId': salonId});
  }
}
