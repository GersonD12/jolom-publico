import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/di/injection.dart';

import '../../application/use_cases/find_nearby_salons_use_case.dart';
import '../../domain/entities/nearby_salon_entity.dart';

final nearbySalonsProvider = FutureProvider.autoDispose
    .family<List<NearbySalon>, SalonSearchArea>((ref, area) {
      return getIt<FindNearbySalonsUseCase>()(area);
    });
