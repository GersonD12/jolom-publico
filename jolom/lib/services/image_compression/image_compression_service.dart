import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Presets de compresión a WebP para fotos del lugar.
class ImageCompressionPreset {
  const ImageCompressionPreset({
    required this.maxWidth,
    required this.quality,
  });

  /// Versión completa (galería / detalle).
  static const placeFull = ImageCompressionPreset(maxWidth: 1600, quality: 80);

  /// Versión rápida de la primera imagen (listados / placeholder).
  static const placeThumb = ImageCompressionPreset(maxWidth: 640, quality: 55);

  final int maxWidth;
  final int quality;
}

/// Compresión genérica de imágenes a WebP (sin Storage).
class ImageCompressionService {
  /// Comprime [bytes] a WebP con [preset] (o parámetros explícitos).
  Future<Uint8List> compressToWebp(
    Uint8List bytes, {
    ImageCompressionPreset preset = ImageCompressionPreset.placeFull,
    int? maxWidth,
    int? quality,
  }) async {
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: maxWidth ?? preset.maxWidth,
      minHeight: maxWidth ?? preset.maxWidth,
      quality: quality ?? preset.quality,
      format: CompressFormat.webp,
    );
    if (result.isEmpty) {
      throw StateError('La compresión WebP no produjo datos.');
    }
    return Uint8List.fromList(result);
  }

  Future<Uint8List> compressPlaceFull(Uint8List bytes) =>
      compressToWebp(bytes, preset: ImageCompressionPreset.placeFull);

  Future<Uint8List> compressPlaceThumb(Uint8List bytes) =>
      compressToWebp(bytes, preset: ImageCompressionPreset.placeThumb);
}
