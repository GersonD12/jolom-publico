import '../../domain/repositories/salon_repository.dart';

/// Acepta o rechaza una invitación de equipo.
class RespondToInvitationUseCase {
  RespondToInvitationUseCase(this._repository);

  final SalonRepository _repository;

  Future<void> call({
    required String invitationId,
    required bool accept,
    String? idempotencyKey,
  }) {
    return _repository.respondToInvitation(
      invitationId: invitationId,
      accept: accept,
      idempotencyKey: idempotencyKey,
    );
  }
}
