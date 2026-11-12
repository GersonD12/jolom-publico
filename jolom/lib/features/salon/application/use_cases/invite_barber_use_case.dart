import '../../domain/repositories/salon_repository.dart';

/// Invita a un peluquero por email.
class InviteBarberUseCase {
  InviteBarberUseCase(this._repository);

  final SalonRepository _repository;

  Future<String> call({
    required String salonId,
    required String inviteeEmail,
    String? idempotencyKey,
  }) {
    return _repository.inviteBarber(
      salonId: salonId,
      inviteeEmail: inviteeEmail,
      idempotencyKey: idempotencyKey,
    );
  }
}
