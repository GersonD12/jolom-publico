import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/features/salon/domain/entities/salon_entity.dart';
import 'package:jolom/features/salon/domain/repositories/salon_repository.dart';
import 'package:jolom/services/user_directory/user_directory.dart';

/// Lectura única de identidad de otro usuario.
final userDirectoryProvider =
    FutureProvider.family<UserDirectoryResult, String>((ref, uid) async {
  if (uid.isEmpty) return MissingUser(uid: uid);
  return getIt<UserDirectoryService>().get(uid);
});

/// Invalida la entrada de caché y el provider.
void invalidateUserDirectory(WidgetRef ref, String uid) {
  getIt<UserDirectoryService>().invalidate(uid);
  ref.invalidate(userDirectoryProvider(uid));
}

/// Limpia toda la caché del directorio y fuerza relectura de proveedores.
void clearUserDirectory(WidgetRef ref) {
  getIt<UserDirectoryService>().clear();
  ref.invalidate(userDirectoryProvider);
}

/// Nombre de peluquería por [salonId] (dato vivo).
final salonByIdProvider = FutureProvider.family<Salon?, String>((ref, salonId) {
  if (salonId.isEmpty) return Future.value(null);
  return getIt<SalonRepository>().getSalon(salonId);
});
