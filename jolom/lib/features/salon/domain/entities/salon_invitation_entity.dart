/// Estado de una invitación de equipo.
enum InvitationStatus {
  pending,
  accepted,
  rejected,
  expired,
  invalidated,
}

/// Invitación a unirse a una peluquería.
class SalonInvitation {
  const SalonInvitation({
    required this.id,
    required this.salonId,
    required this.inviterId,
    required this.inviteeId,
    required this.inviteeEmail,
    required this.status,
    required this.expiresAt,
  });

  final String id;
  final String salonId;
  final String inviterId;
  final String inviteeId;
  final String inviteeEmail;
  final InvitationStatus status;
  final DateTime expiresAt;

  bool get isPending => status == InvitationStatus.pending;

  factory SalonInvitation.fromMap(
    String id,
    Map<String, dynamic> map, {
    required DateTime expiresAt,
  }) {
    return SalonInvitation(
      id: id,
      salonId: map['salonId'] as String? ?? '',
      inviterId: map['inviterId'] as String? ?? '',
      inviteeId: map['inviteeId'] as String? ?? '',
      inviteeEmail: map['inviteeEmail'] as String? ?? '',
      status: InvitationStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => InvitationStatus.expired,
      ),
      expiresAt: expiresAt,
    );
  }
}
