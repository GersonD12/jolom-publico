import 'package:flutter/material.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/shared/widgets/pressable_scale_widget.dart';

/// Tarjeta editorial para descubrir un salón.
///
/// La fotografía ocupa toda la superficie y el degradado inferior mantiene
/// legibles el nombre y la descripción sin añadir datos que aún no existen.
class SalonCardWidget extends StatelessWidget {
  const SalonCardWidget({
    required this.name,
    required this.image,
    this.subtitle,
    this.heroTag,
    this.onTap,
    this.aspectRatio = 0.82,
    super.key,
  });

  final String name;
  final Widget image;

  /// Descripción breve del salón.
  final String? subtitle;
  final Object? heroTag;
  final VoidCallback? onTap;

  /// Relación ancho/alto de la tarjeta fotográfica.
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final softUi = SoftUiTheme.of(context);
    final radius = AppRadius.cardLarge;
    final description = subtitle?.trim();

    final photo = SizedBox.expand(child: image);

    return Semantics(
      button: onTap != null,
      label: description == null || description.isEmpty
          ? name
          : '$name. $description',
      child: PressableScaleWidget(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: radius,
              boxShadow: softUi.cardShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (heroTag != null)
                  Hero(tag: heroTag!, child: photo)
                else
                  photo,
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0x12000000),
                        Color(0xC9000000),
                        Color(0xF0000000),
                      ],
                      stops: [0.42, 0.58, 0.78, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 58),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            height: 1.08,
                            shadows: const [
                              Shadow(
                                color: Color(0x66000000),
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        if (description != null && description.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.72),
                              height: 1.25,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: IgnorePointer(
                    child: Container(
                      width: AppSpacing.minTapTarget,
                      height: AppSpacing.minTapTarget,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.09),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 22,
                        color: scheme.brightness == Brightness.dark
                            ? scheme.primary
                            : scheme.primaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
