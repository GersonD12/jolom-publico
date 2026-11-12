import '../entities/salon_entity.dart';
import '../entities/nearby_salon_entity.dart';
import '../entities/salon_invitation_entity.dart';
import '../entities/salon_membership_entity.dart';
import '../entities/service_entity.dart';

/// Contrato de peluquerías, servicios, pertenencia e invitaciones.
abstract class SalonRepository {
  Future<Salon> createSalon({
    required String name,
    String? description,
    String? contactPhone,
    String? address,
    String? idempotencyKey,
  });

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
  });

  Future<void> setSalonPublishStatus({
    required String salonId,
    required SalonPublishStatus publishStatus,
    String? idempotencyKey,
  });

  Future<Salon?> getSalon(String salonId);

  Stream<List<Salon>> watchPublishedSalons({int limit = 50});

  Future<List<NearbySalon>> listPublishedSalonsNearby(SalonSearchArea area);

  Future<List<Service>> listServices(
    String salonId, {
    bool includeInactive = false,
  });

  Future<String> createService({
    required String salonId,
    required String name,
    required int durationMinutes,
    required double price,
    String? description,
    List<String>? enabledBarberIds,
    String? idempotencyKey,
  });

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
  });

  Future<SalonMembership?> getMembership(String userId);

  Stream<SalonMembership?> watchMembership(String userId);

  /// Miembros del salón. Por defecto solo `active` (reserva pública).
  /// Con [includePendingExit] el owner ve también salidas pendientes (equipo).
  Future<List<SalonMembership>> listSalonMembers(
    String salonId, {
    bool includePendingExit = false,
  });

  Future<String> inviteBarber({
    required String salonId,
    required String inviteeEmail,
    String? idempotencyKey,
  });

  Future<void> respondToInvitation({
    required String invitationId,
    required bool accept,
    String? idempotencyKey,
  });

  Future<List<SalonInvitation>> listPendingInvitationsForUser(String userId);

  Future<Map<String, dynamic>> beginMembershipExit({
    String? targetUserId,
    String? idempotencyKey,
  });

  Future<void> completeMembershipExit({
    String? targetUserId,
    String? idempotencyKey,
  });

  Future<void> recordQrOpen(String salonId);
}
