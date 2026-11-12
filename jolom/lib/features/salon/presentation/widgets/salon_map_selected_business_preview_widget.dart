import 'package:flutter/material.dart';
import 'package:jolom/core/theme/theme.dart';

import '../../domain/entities/nearby_salon_entity.dart';
import 'place_gallery_preview_widget.dart';
import 'salon_image_widget.dart';

/// Vista previa amplia que aparece al seleccionar un marcador del mapa.
class SalonMapSelectedBusinessPreviewWidget extends StatelessWidget {
  const SalonMapSelectedBusinessPreviewWidget({
    required this.item,
    required this.onClose,
    required this.onOpen,
    super.key,
  });

  final NearbySalon item;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final address = item.salon.address?.trim();
    final location = address != null && address.isNotEmpty
        ? address
        : item.salon.city;
    final hasImages =
        item.salon.imageUrls.isNotEmpty ||
        (item.salon.coverImageUrl?.trim().isNotEmpty ?? false);

    return Material(
      elevation: 8,
      color: scheme.surface,
      borderRadius: AppRadius.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 148,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImages)
                    PlaceGalleryPreviewWidget(
                      imageUrls: item.salon.imageUrls,
                      coverImageUrl: item.salon.coverImageUrl,
                      height: 148,
                      borderRadius: BorderRadius.zero,
                      indicatorStyle: PlaceGalleryIndicatorStyle.dots,
                    )
                  else
                    SalonImageWidget(
                      salon: item.salon,
                      placeholderColor: scheme.primaryContainer,
                      fallbackIconSize: 52,
                    ),
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: Material(
                      elevation: 2,
                      color: scheme.surface.withValues(alpha: 0.94),
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: onClose,
                        tooltip: 'Cerrar negocio seleccionado',
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.salon.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${_formatDistance(item.distanceKm)} · $location',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.primary,
                    size: 30,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDistance(double distanceKm) {
  if (distanceKm < 1) return '${(distanceKm * 1000).round()} m';
  return '${distanceKm.toStringAsFixed(1)} km';
}
