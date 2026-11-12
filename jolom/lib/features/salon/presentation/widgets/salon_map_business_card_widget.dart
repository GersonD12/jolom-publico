import 'package:flutter/material.dart';
import 'package:jolom/core/theme/theme.dart';

import '../../domain/entities/nearby_salon_entity.dart';
import 'salon_image_widget.dart';

/// Tarjeta inferior compacta del negocio seleccionado en el mapa.
class SalonMapBusinessCardWidget extends StatelessWidget {
  const SalonMapBusinessCardWidget({
    required this.item,
    required this.onOpen,
    this.onCardTap,
    this.onClose,
    super.key,
  });

  final NearbySalon item;
  final VoidCallback onOpen;
  final VoidCallback? onCardTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final address = item.salon.address?.trim();
    final locationLabel = address != null && address.isNotEmpty
        ? address
        : item.salon.city;
    final openActionColor = Color.alphaBlend(
      theme.colorScheme.primary.withValues(alpha: 0.12),
      theme.colorScheme.surface,
    );
    return Material(
      elevation: 5,
      color: theme.colorScheme.surface,
      borderRadius: AppRadius.cardCompact,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 88,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onCardTap ?? onOpen,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: AppRadius.cardCompact,
                        child: SizedBox.square(
                          dimension: 64,
                          child: SalonImageWidget(
                            salon: item.salon,
                            placeholderColor:
                                theme.colorScheme.primaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.salon.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              '${_formatSalonDistance(item.distanceKm)} de distancia',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onClose != null)
                        IconButton(
                          onPressed: onClose,
                          tooltip: 'Cerrar',
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: theme.colorScheme.outlineVariant,
            ),
            SizedBox(
              width: 58,
              child: Material(
                color: openActionColor,
                child: InkWell(
                  onTap: onOpen,
                  child: Tooltip(
                    message: 'Ver negocio',
                    child: Center(
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 30,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatSalonDistance(double distanceKm) {
  if (distanceKm < 1) return '${(distanceKm * 1000).round()} m';
  return '${distanceKm.toStringAsFixed(1)} km';
}
