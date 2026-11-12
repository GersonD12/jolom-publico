import 'package:jolom/core/domain/entities/user_entity.dart';

/// Contrato de autenticación. La UI y los use cases solo conocen esta interfaz.
abstract class AuthRepository {
  /// Stream de cambios de sesión (login / logout).
  Stream<UserEntity?> authStateChanges();

  /// Usuario actual, o `null` si no hay sesión.
  UserEntity? get currentUser;

  /// Envía un vínculo que crea la cuenta o inicia sesión al abrirse.
  Future<void> sendEmailSignInLink(String email);

  /// Indica si [emailLink] es un vínculo válido de acceso por correo.
  bool isEmailSignInLink(String emailLink);

  /// Completa el acceso sin contraseña con el correo y vínculo recibidos.
  Future<UserEntity> signInWithEmailLink({
    required String email,
    required String emailLink,
  });

  /// Inicia sesión con una cuenta existente que conserva contraseña.
  Future<UserEntity> signInWithEmailPassword({
    required String email,
    required String password,
  });

  /// Inicia sesión con Google.
  Future<UserEntity> signInWithGoogle();

  /// Inicia sesión con Apple.
  Future<UserEntity> signInWithApple();

  /// Cierra la sesión actual.
  Future<void> signOut();

  /// Actualiza el nombre visible en Auth y en `users/{uid}`.
  Future<void> updateDisplayName(String displayName);

  /// Perfil hidratado desde `users/{uid}` (Firestore). Devuelve `null` si no hay doc.
  Future<UserEntity?> fetchUserProfile(String uid);

  /// Perfil en tiempo real para bloquear cambios de estado de cuenta.
  Stream<UserEntity?> watchUserProfile(String uid);
}
