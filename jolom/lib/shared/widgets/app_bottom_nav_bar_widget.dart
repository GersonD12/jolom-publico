import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/shared/widgets/pressable_scale_widget.dart';

/// Destino configurable de la navegación inferior general de la app.
@immutable
class AppBottomNavDestination {
  const AppBottomNavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.showAttentionIndicator = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool showAttentionIndicator;
}

/// Barra inferior integrada, compartida por los modos cliente y trabajo.
///
/// La misma superficie cubre los destinos y el área segura del dispositivo,
/// evitando el bloque visual que aparecía detrás de la antigua isla flotante.
class AppBottomNavBarWidget extends StatelessWidget {
  const AppBottomNavBarWidget({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppBottomNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    assert(destinations.isNotEmpty);
    assert(currentIndex >= 0 && currentIndex < destinations.length);

    final softUi = SoftUiTheme.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final backgroundColor = softUi.navBarColor.withValues(alpha: 0.86);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                bottomInset + AppSpacing.xs,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Expanded(
                      child: _NavItem(
                        destination: destinations[i],
                        selected: currentIndex == i,
                        onTap: () => onDestinationSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppBottomNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final duration = AppMotion.durationOf(context, AppMotion.fast);
    final color = selected
        ? colorScheme.brightness == Brightness.dark
              ? colorScheme.primary
              : colorScheme.primaryContainer
        : Colors.white.withValues(alpha: 0.56);

    return Semantics(
      button: true,
      selected: selected,
      label: destination.showAttentionIndicator
          ? '${destination.label}, configuración pendiente'
          : destination.label,
      excludeSemantics: true,
      child: PressableScaleWidget(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: duration,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: SizedBox(
                  key: ValueKey((selected, destination.showAttentionIndicator)),
                  width: 28,
                  height: 25,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        selected ? destination.selectedIcon : destination.icon,
                        size: 23,
                        color: color,
                      ),
                      if (destination.showAttentionIndicator)
                        Positioned(
                          key: ValueKey('nav-attention-${destination.label}'),
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: colorScheme.error,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: SoftUiTheme.of(context).navBarColor,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: duration,
                curve: AppMotion.curveOf(context, AppMotion.decelerate),
                style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
