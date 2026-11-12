/// Estado operativo de la cuenta independiente de la moderación.
enum AccountStatus {
  active,
  deletionPending,
  deleting,
  deleted;

  bool get blocksAccess => this != AccountStatus.active;

  static AccountStatus fromValue(Object? value) {
    return AccountStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => AccountStatus.active,
    );
  }
}

/// Entidad de usuario compartida en toda la app.
class UserEntity {
  const UserEntity({
    required this.id,
    this.email,
    this.displayName,
    this.photoUrl,
    this.phone,
    this.isAnonymous = false,
    this.isBarber = false,
    this.isBanned = false,
    this.isDeleted = false,
    this.moderationStatus = 'none',
    this.moderationReason,
    this.accountStatus = AccountStatus.active,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? phone;
  final bool isAnonymous;
  final bool isBarber;
  final bool isBanned;
  final bool isDeleted;
  final String moderationStatus;
  final String? moderationReason;
  final AccountStatus accountStatus;

  bool get isAuthenticated => id.isNotEmpty;

  bool get isModerationBlocked => isBanned || moderationStatus == 'banned';

  /// Nombre preferido para dirigirse al usuario (nunca el email).
  String? get preferredDisplayName {
    final name = displayName?.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }

  UserEntity copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    String? phone,
    bool? isAnonymous,
    bool? isBarber,
    bool? isBanned,
    bool? isDeleted,
    String? moderationStatus,
    String? moderationReason,
    AccountStatus? accountStatus,
  }) {
    return UserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      phone: phone ?? this.phone,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isBarber: isBarber ?? this.isBarber,
      isBanned: isBanned ?? this.isBanned,
      isDeleted: isDeleted ?? this.isDeleted,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      moderationReason: moderationReason ?? this.moderationReason,
      accountStatus: accountStatus ?? this.accountStatus,
    );
  }

  /// Hidrata campos del documento `users/{uid}`.
  factory UserEntity.fromFirestoreMap(
    String id,
    Map<String, dynamic> map, {
    bool isAnonymous = false,
  }) {
    final capabilities = map['capabilities'];
    final isBarber = capabilities is Map && capabilities['barber'] == true;
    return UserEntity(
      id: id,
      email: map['email'] as String?,
      displayName: map['displayName'] as String?,
      photoUrl: map['photoUrl'] as String?,
      phone: map['phone'] as String?,
      isAnonymous: isAnonymous,
      isBarber: isBarber,
      isBanned: map['isBanned'] as bool? ?? false,
      isDeleted: map['isDeleted'] as bool? ?? false,
      moderationStatus: map['moderationStatus'] as String? ?? 'none',
      moderationReason: map['moderationReason'] as String?,
      accountStatus: AccountStatus.fromValue(map['accountStatus']),
    );
  }
}
