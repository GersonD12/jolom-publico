import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/domain/entities/user_entity.dart';
import 'package:jolom/features/auth/domain/repositories/auth_repository.dart';

/// Estado de acceso usado por navegación y guards de rutas protegidas.
enum AppAccessStatus {
  loading,
  sessionError,
  unauthenticated,
  blocked,
  restricted,
  active,
}

/// Stream de sesión. Se mantiene vivo para no perder el listener de Auth.
final sessionProvider = StreamProvider<UserEntity?>((ref) {
  // Mantener el stream activo mientras viva la app.
  ref.keepAlive();
  final authRepository = getIt<AuthRepository>();
  return authRepository.authStateChanges();
});

/// Perfil vivo usado como compuerta antes de habilitar la navegación privada.
/// Un documento inexistente mantiene la app en aprovisionamiento hasta que el
/// trigger `onUserCreated` complete `users/{uid}`.
final accountProfileProvider = StreamProvider<UserEntity?>((ref) {
  ref.keepAlive();
  final session = ref.watch(sessionProvider).value;
  if (session == null) return Stream.value(null);
  return getIt<AuthRepository>().watchUserProfile(session.id);
});

final appAccessStatusProvider = Provider<AppAccessStatus>((ref) {
  final session = ref.watch(sessionProvider);
  if (session.isLoading) return AppAccessStatus.loading;
  if (session.hasError) return AppAccessStatus.sessionError;
  if (session.value == null) {
    return AppAccessStatus.unauthenticated;
  }

  final profile = ref.watch(accountProfileProvider);
  if (profile.isLoading || profile.value == null) {
    return AppAccessStatus.loading;
  }
  if (profile.value!.accountStatus.blocksAccess || profile.value!.isDeleted) {
    return AppAccessStatus.blocked;
  }
  if (profile.value!.isModerationBlocked) {
    return AppAccessStatus.restricted;
  }
  return AppAccessStatus.active;
});

/// Sesión hidratada con `users/{uid}` (lectura única).
///
/// Combina Auth (id / anónimo) con Firestore (displayName, photoUrl, etc.).
/// Invalidar con [ref.invalidate] para forzar rehidratación (p. ej. pull-to-refresh).
final hydratedSessionProvider = FutureProvider<UserEntity?>((ref) async {
  final session = ref.watch(sessionProvider).value;
  if (session == null) return null;

  final profile = await getIt<AuthRepository>().fetchUserProfile(session.id);
  if (profile == null) return session;
  return session.copyWith(
    email: profile.email ?? session.email,
    displayName: profile.displayName ?? session.displayName,
    photoUrl: profile.photoUrl ?? session.photoUrl,
    phone: profile.phone ?? session.phone,
    isBarber: profile.isBarber,
    isBanned: profile.isBanned,
    isDeleted: profile.isDeleted,
    moderationStatus: profile.moderationStatus,
    moderationReason: profile.moderationReason,
    accountStatus: profile.accountStatus,
  );
});
