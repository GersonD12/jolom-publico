import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:jolom/features/salon/domain/entities/place_gallery_entry.dart';
import 'package:jolom/services/image_compression/image_compression.dart';
import 'package:uuid/uuid.dart';

/// Sube y sincroniza fotos del lugar en `negocios/{salonId}/lugar/`.
class PlaceImageStorageService {
  PlaceImageStorageService({
    FirebaseStorage? storage,
    ImageCompressionService? compression,
    Uuid? uuid,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _compression = compression ?? ImageCompressionService(),
        _uuid = uuid ?? const Uuid();

  static const maxImages = 10;

  final FirebaseStorage _storage;
  final ImageCompressionService _compression;
  final Uuid _uuid;

  String _folder(String salonId) => 'negocios/$salonId/lugar';

  /// Sincroniza [entries] (máx. 10): sube locales, regenera thumb de la primera
  /// y elimina objetos huérfanos en la carpeta.
  Future<PlaceGallerySyncResult> syncPlaceImages({
    required String salonId,
    required List<PlaceGalleryEntry> entries,
    String? previousFirstImageUrl,
    String? previousCoverImageUrl,
  }) async {
    if (entries.length > maxImages) {
      throw ArgumentError(
        'Máximo $maxImages imágenes del lugar (recibidas: ${entries.length}).',
      );
    }

    final folderRef = _storage.ref(_folder(salonId));
    final keepPaths = <String>{};
    final imageUrls = <String>[];
    String? coverImageUrl;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final isFirst = i == 0;

      switch (entry) {
        case LocalPlaceGalleryEntry(:final bytes):
          final id = _uuid.v4();
          final fullBytes = await _compression.compressPlaceFull(bytes);
          final fullRef = folderRef.child('$id.webp');
          await fullRef.putData(
            fullBytes,
            SettableMetadata(contentType: 'image/webp'),
          );
          keepPaths.add(fullRef.fullPath);
          final fullUrl = await fullRef.getDownloadURL();
          imageUrls.add(fullUrl);

          if (isFirst) {
            coverImageUrl = await _uploadThumb(
              folderRef: folderRef,
              id: id,
              sourceBytes: bytes,
              keepPaths: keepPaths,
            );
          }
        case RemotePlaceGalleryEntry(:final url):
          imageUrls.add(url);
          final path = storagePathFromDownloadUrl(url);
          if (path != null) keepPaths.add(path);

          if (isFirst) {
            final canReuseCover = previousFirstImageUrl == url &&
                previousCoverImageUrl != null &&
                previousCoverImageUrl.isNotEmpty;
            if (canReuseCover) {
              coverImageUrl = previousCoverImageUrl;
              final coverPath = storagePathFromDownloadUrl(previousCoverImageUrl);
              if (coverPath != null) keepPaths.add(coverPath);
            } else {
              final sourceBytes = await _downloadBytes(url);
              final id = _uuid.v4();
              coverImageUrl = await _uploadThumb(
                folderRef: folderRef,
                id: id,
                sourceBytes: sourceBytes,
                keepPaths: keepPaths,
              );
            }
          }
      }
    }

    await _deleteOrphans(folderRef, keepPaths);

    return PlaceGallerySyncResult(
      imageUrls: imageUrls,
      coverImageUrl: coverImageUrl,
    );
  }

  Future<String> _uploadThumb({
    required Reference folderRef,
    required String id,
    required Uint8List sourceBytes,
    required Set<String> keepPaths,
  }) async {
    final thumbBytes = await _compression.compressPlaceThumb(sourceBytes);
    final thumbRef = folderRef.child('${id}_thumb.webp');
    await thumbRef.putData(
      thumbBytes,
      SettableMetadata(contentType: 'image/webp'),
    );
    keepPaths.add(thumbRef.fullPath);
    return thumbRef.getDownloadURL();
  }

  Future<void> _deleteOrphans(
    Reference folderRef,
    Set<String> keepPaths,
  ) async {
    try {
      final listed = await folderRef.listAll();
      for (final item in listed.items) {
        if (!keepPaths.contains(item.fullPath)) {
          try {
            await item.delete();
          } catch (_) {
            // Best-effort: no bloquear el guardado si falla un delete.
          }
        }
      }
    } catch (_) {
      // Carpeta vacía o sin permiso de listado.
    }
  }

  Future<Uint8List> _downloadBytes(String url) async {
    final request = await HttpClient().getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('No se pudo descargar la imagen ($url).');
    }
    return consolidateHttpClientResponseBytes(response);
  }

  /// Extrae el path de objeto Storage desde una download URL de Firebase.
  @visibleForTesting
  static String? storagePathFromDownloadUrl(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    final oIndex = segments.indexOf('o');
    if (oIndex < 0 || oIndex + 1 >= segments.length) return null;
    return Uri.decodeComponent(segments[oIndex + 1]);
  }
}
