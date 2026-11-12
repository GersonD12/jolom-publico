import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/salon_entity.dart';

/// Imagen de negocio con caché y respaldo visual consistente.
class SalonImageWidget extends StatelessWidget {
  const SalonImageWidget({
    required this.salon,
    required this.placeholderColor,
    this.fit = BoxFit.cover,
    this.fallbackIconSize = 40,
    super.key,
  });

  final Salon salon;
  final Color placeholderColor;
  final BoxFit fit;
  final double fallbackIconSize;

  @override
  Widget build(BuildContext context) {
    final imageUrl = salonPrimaryImageUrl(salon);
    if (imageUrl == null) return _placeholder();
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      placeholder: (_, _) => _placeholder(),
      errorWidget: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder() => ColoredBox(
    color: placeholderColor,
    child: Center(child: Icon(Icons.storefront, size: fallbackIconSize)),
  );
}

/// Obtiene la mejor imagen disponible para representar una peluquería.
String? salonPrimaryImageUrl(Salon salon) {
  final cover = salon.coverImageUrl?.trim();
  if (cover != null && cover.isNotEmpty) return cover;
  for (final imageUrl in salon.imageUrls) {
    final normalized = imageUrl.trim();
    if (normalized.isNotEmpty) return normalized;
  }
  return null;
}
