import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

enum PlaceGalleryIndicatorStyle { counter, dots }

/// Carrusel de fotos del lugar: thumb de portada como placeholder de la primera.
class PlaceGalleryPreviewWidget extends StatefulWidget {
  const PlaceGalleryPreviewWidget({
    required this.imageUrls,
    this.coverImageUrl,
    this.height = 200,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.indicatorStyle = PlaceGalleryIndicatorStyle.counter,
    super.key,
  });

  final List<String> imageUrls;
  final String? coverImageUrl;
  final double height;
  final PlaceGalleryIndicatorStyle indicatorStyle;

  /// Esquinas; [BorderRadius.zero] para estilo edge-to-edge (infinito).
  final BorderRadius borderRadius;

  @override
  State<PlaceGalleryPreviewWidget> createState() =>
      _PlaceGalleryPreviewWidgetState();
}

class _PlaceGalleryPreviewWidgetState extends State<PlaceGalleryPreviewWidget> {
  int _pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty &&
        (widget.coverImageUrl == null || widget.coverImageUrl!.isEmpty)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final urls = widget.imageUrls.isNotEmpty
        ? widget.imageUrls
        : [?widget.coverImageUrl];
    final total = urls.length;
    final current = (_pageIndex + 1).clamp(1, total);

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: urls.length,
            onPageChanged: (index) => setState(() => _pageIndex = index),
            itemBuilder: (context, index) {
              final url = urls[index];
              final useThumbPlaceholder =
                  index == 0 &&
                  widget.coverImageUrl != null &&
                  widget.coverImageUrl!.isNotEmpty &&
                  widget.coverImageUrl != url;

              return ClipRRect(
                borderRadius: widget.borderRadius,
                child: useThumbPlaceholder
                    ? CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: widget.height,
                        placeholder: (_, _) => CachedNetworkImage(
                          imageUrl: widget.coverImageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: widget.height,
                        ),
                        errorWidget: (_, _, _) => _errorBox(context),
                      )
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: widget.height,
                        errorWidget: (_, _, _) => _errorBox(context),
                      ),
              );
            },
          ),
          if (widget.indicatorStyle == PlaceGalleryIndicatorStyle.counter)
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$current / $total',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(total, (index) {
                    final selected = index == _pageIndex;
                    return AnimatedContainer(
                      key: ValueKey(
                        'gallery-dot-$index-${selected ? 'selected' : 'idle'}',
                      ),
                      duration: const Duration(milliseconds: 180),
                      width: selected ? 10 : 8,
                      height: selected ? 10 : 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(
                          alpha: selected ? 1 : 0.58,
                        ),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _errorBox(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.broken_image_outlined)),
    );
  }
}
