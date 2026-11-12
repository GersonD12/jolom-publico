import 'package:flutter/material.dart';
import 'package:jolom/core/theme/theme.dart';

import 'current_location_indicator_widget.dart';

/// Control superior para volver a la ubicación actual.
class SalonMapControlsWidget extends StatelessWidget {
  const SalonMapControlsWidget({
    required this.locating,
    required this.onUseCurrentLocation,
    super.key,
  });

  final bool locating;
  final VoidCallback onUseCurrentLocation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: 'Mi ubicación',
        child: FilledButton.tonal(
          onPressed: locating ? null : onUseCurrentLocation,
          style: FilledButton.styleFrom(
            minimumSize: const Size.square(48),
            padding: EdgeInsets.zero,
            backgroundColor: scheme.surface,
            foregroundColor: scheme.onSurface,
            disabledBackgroundColor: scheme.surface,
            disabledForegroundColor: scheme.onSurfaceVariant,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.pill),
            elevation: 2,
          ),
          child: locating
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const CurrentLocationIndicatorWidget(),
        ),
      ),
    );
  }
}
