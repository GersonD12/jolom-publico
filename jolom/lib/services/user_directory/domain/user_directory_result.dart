/// Resultado de resolver un usuario ajeno vía directorio.
sealed class UserDirectoryResult {
  const UserDirectoryResult();
}

/// Usuario visible (no baneado / no eliminado).
class VisibleUser extends UserDirectoryResult {
  const VisibleUser({
    required this.uid,
    this.displayName,
    this.photoUrl,
  });

  final String uid;
  final String? displayName;
  final String? photoUrl;
}

/// Usuario oculto por ban o soft-delete.
class HiddenUser extends UserDirectoryResult {
  const HiddenUser({required this.uid});

  final String uid;
}

/// Documento de perfil inexistente.
class MissingUser extends UserDirectoryResult {
  const MissingUser({required this.uid});

  final String uid;
}
