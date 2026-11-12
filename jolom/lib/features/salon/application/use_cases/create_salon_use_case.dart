import '../../domain/entities/salon_entity.dart';
import '../../domain/repositories/salon_repository.dart';

/// Crea una peluquería vía Cloud Function.
class CreateSalonUseCase {
  CreateSalonUseCase(this._repository);

  final SalonRepository _repository;

  Future<Salon> call({
    required String name,
    String? description,
    String? contactPhone,
    String? address,
    String? idempotencyKey,
  }) {
    return _repository.createSalon(
      name: name,
      description: description,
      contactPhone: contactPhone,
      address: address,
      idempotencyKey: idempotencyKey,
    );
  }
}
