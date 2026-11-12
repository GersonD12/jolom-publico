/// Rol dentro de una pertenencia a peluquería.
enum MembershipRole { owner, barber }

/// Etiqueta en español para UI (el valor en Firestore sigue en inglés).
extension MembershipRoleLabel on MembershipRole {
  String get labelEs => switch (this) {
    MembershipRole.owner => 'Propietario',
    MembershipRole.barber => 'Peluquero',
  };
}

/// Estado de la pertenencia.
enum MembershipStatus { active, pendingExit, withdrawn }

/// Etiqueta en español para UI (el valor en Firestore sigue en inglés).
extension MembershipStatusLabel on MembershipStatus {
  String get labelEs => switch (this) {
    MembershipStatus.active => 'Activo',
    MembershipStatus.pendingExit => 'Salida pendiente',
    MembershipStatus.withdrawn => 'Retirado',
  };
}

/// Pertenencia peluquero ↔ peluquería (`salonMemberships/{uid}`).
class SalonMembership {
  const SalonMembership({
    required this.userId,
    required this.salonId,
    required this.role,
    required this.status,
    this.invitationId,
  });

  final String userId;
  final String salonId;
  final MembershipRole role;
  final MembershipStatus status;
  final String? invitationId;

  bool get isActive => status == MembershipStatus.active;
  bool get isOwner => role == MembershipRole.owner;

  factory SalonMembership.fromMap(String userId, Map<String, dynamic> map) {
    return SalonMembership(
      userId: userId,
      salonId: map['salonId'] as String? ?? '',
      role: map['role'] == 'owner'
          ? MembershipRole.owner
          : MembershipRole.barber,
      status: _parseStatus(map['status'] as String?),
      invitationId: map['invitationId'] as String?,
    );
  }

  static MembershipStatus _parseStatus(String? value) {
    return MembershipStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MembershipStatus.withdrawn,
    );
  }
}
