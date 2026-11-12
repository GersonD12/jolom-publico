import 'dart:typed_data';

/// Entrada de la galería del lugar antes de sincronizar con Storage.
sealed class PlaceGalleryEntry {
  const PlaceGalleryEntry();
}

/// Imagen ya publicada (URL de descarga de Storage).
class RemotePlaceGalleryEntry extends PlaceGalleryEntry {
  const RemotePlaceGalleryEntry(this.url);

  final String url;
}

/// Imagen nueva elegida en el dispositivo.
class LocalPlaceGalleryEntry extends PlaceGalleryEntry {
  const LocalPlaceGalleryEntry(this.bytes);

  final Uint8List bytes;
}

/// Resultado de subir/sincronizar la galería del lugar.
class PlaceGallerySyncResult {
  const PlaceGallerySyncResult({
    required this.imageUrls,
    this.coverImageUrl,
  });

  final List<String> imageUrls;
  final String? coverImageUrl;
}
