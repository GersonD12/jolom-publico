import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';
import 'package:jolom/shared/widgets/salon_card_widget.dart';

import '../../domain/entities/salon_entity.dart';
import 'salon_image_widget.dart';

/// Lista de peluquerías publicadas dentro de Explorar.
class SalonExploreListWidget extends ConsumerWidget {
  const SalonExploreListWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salonsAsync = ref.watch(publishedSalonsProvider);
    return salonsAsync.when(
      data: (salons) {
        if (salons.isEmpty) {
          return const Center(
            child: Text('No hay peluquerías publicadas todavía.'),
          );
        }
        return ListView.separated(
          padding: appScrollPadding(
            context,
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
            bottom: AppSpacing.xxxl,
          ),
          itemCount: salons.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) => _SalonListCard(salon: salons[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text(userFacingError(error, stackTrace))),
    );
  }
}

class _SalonListCard extends StatelessWidget {
  const _SalonListCard({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context) {
    final placeholderColor = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest;
    final description = salon.description?.trim();
    return SalonCardWidget(
      name: salon.name,
      image: SalonImageWidget(salon: salon, placeholderColor: placeholderColor),
      subtitle: description != null && description.isNotEmpty
          ? description
          : null,
      onTap: () => context.push('/salon/${salon.id}'),
    );
  }
}
