import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jolom/features/salon/domain/entities/place_gallery_entry.dart';
import 'package:jolom/features/salon/infrastructure/place_image_storage_service.dart';
import 'package:jolom/shared/widgets/app_modal_bottom_sheet.dart';

/// Item editable de la galería (local o remoto).
class EditablePlaceImage {
  EditablePlaceImage.remote(String remoteUrl) : url = remoteUrl, bytes = null;

  EditablePlaceImage.local(Uint8List localBytes)
    : url = null,
      bytes = localBytes;

  final String? url;
  final Uint8List? bytes;

  bool get isLocal => bytes != null;

  PlaceGalleryEntry toEntry() {
    if (bytes != null) return LocalPlaceGalleryEntry(bytes!);
    return RemotePlaceGalleryEntry(url!);
  }
}

/// Grid para gestionar hasta [PlaceImageStorageService.maxImages] fotos del lugar.
class PlaceGalleryEditorWidget extends StatelessWidget {
  const PlaceGalleryEditorWidget({
    required this.images,
    required this.onChanged,
    super.key,
  });

  final List<EditablePlaceImage> images;
  final ValueChanged<List<EditablePlaceImage>> onChanged;

  Future<void> _pick(BuildContext context) async {
    if (images.length >= PlaceImageStorageService.maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Máximo ${PlaceImageStorageService.maxImages} imágenes.',
          ),
        ),
      );
      return;
    }

    final source = await showAppModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final remaining = PlaceImageStorageService.maxImages - images.length;
    if (source == ImageSource.gallery && remaining > 1) {
      final files = await picker.pickMultiImage(
        imageQuality: 95,
        limit: remaining,
      );
      if (files.isEmpty) return;
      final next = List<EditablePlaceImage>.from(images);
      for (final file in files) {
        if (next.length >= PlaceImageStorageService.maxImages) break;
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        next.add(EditablePlaceImage.local(bytes));
      }
      onChanged(next);
      return;
    }

    final file = await picker.pickImage(source: source, imageQuality: 95);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return;
    onChanged([...images, EditablePlaceImage.local(bytes)]);
  }

  void _remove(int index) {
    final next = List<EditablePlaceImage>.from(images)..removeAt(index);
    onChanged(next);
  }

  void _makeFirst(int index) {
    if (index <= 0 || index >= images.length) return;
    final next = List<EditablePlaceImage>.from(images);
    final item = next.removeAt(index);
    next.insert(0, item);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fotos del lugar', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Máximo ${PlaceImageStorageService.maxImages}. La primera se muestra '
          'como portada (con vista rápida).',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: images.length < PlaceImageStorageService.maxImages
              ? images.length + 1
              : images.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            if (index >= images.length) {
              return InkWell(
                onTap: () => _pick(context),
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: const Center(child: Icon(Icons.add_a_photo_outlined)),
                ),
              );
            }

            final image = images[index];
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: image.bytes != null
                      ? Image.memory(image.bytes!, fit: BoxFit.cover)
                      : CachedNetworkImage(
                          imageUrl: image.url!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) =>
                              const ColoredBox(color: Colors.black12),
                        ),
                ),
                if (index == 0)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Principal',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _remove(index),
                  ),
                ),
                if (index > 0)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: IconButton(
                      tooltip: 'Hacer principal',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(32, 32),
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.star_outline, size: 18),
                      onPressed: () => _makeFirst(index),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
