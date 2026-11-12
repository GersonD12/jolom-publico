import '../../domain/entities/nearby_salon_entity.dart';
import '../../domain/repositories/salon_repository.dart';

/// Busca peluquerías publicadas dentro de un círculo de hasta 50 km.
class FindNearbySalonsUseCase {
  FindNearbySalonsUseCase(this._repository);

  final SalonRepository _repository;

  Future<List<NearbySalon>> call(SalonSearchArea area) {
    if (!area.center.isValid) {
      throw ArgumentError('La ubicación seleccionada no es válida.');
    }
    if (area.radiusKm <= 0 || area.radiusKm > 50) {
      throw ArgumentError('El radio debe estar entre 1 y 50 km.');
    }
    return _repository.listPublishedSalonsNearby(area);
  }
}
