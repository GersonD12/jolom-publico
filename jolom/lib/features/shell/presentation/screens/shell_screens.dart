import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/shared/widgets/app_bottom_nav_bar_widget.dart';

const _clientDestinations = [
  AppBottomNavDestination(
    label: 'Inicio',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  AppBottomNavDestination(
    label: 'Explorar',
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore_rounded,
  ),
  AppBottomNavDestination(
    label: 'Citas',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month_rounded,
  ),
  AppBottomNavDestination(
    label: 'Perfil',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

/// Shell cliente con navegación inferior.
class ClientShellScreen extends ConsumerWidget {
  const ClientShellScreen({required this.child, super.key});

  final Widget child;

  static int _indexForLocation(String location) {
    if (location.startsWith('/explore')) return 1;
    if (location.startsWith('/appointments')) return 2;
    if (location.startsWith('/profile') ||
        location.startsWith('/notifications')) {
      return 3;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexForLocation(location);

    return _AppShellScaffold(
      routeKey: location,
      currentIndex: index,
      destinations: _clientDestinations,
      onDestinationSelected: (i) {
        switch (i) {
          case 0:
            context.go('/home');
          case 1:
            context.go('/explore');
          case 2:
            context.go('/appointments');
          case 3:
            context.go('/profile');
        }
      },
      child: child,
    );
  }
}

/// Shell modo trabajo (peluquero/propietario).
class WorkShellScreen extends ConsumerWidget {
  const WorkShellScreen({required this.child, super.key});

  final Widget child;

  static int _indexForLocation(String location) {
    if (location.startsWith('/work/calendar')) return 1;
    if (location.startsWith('/work/availability')) return 2;
    if (location.startsWith('/work/stats') ||
        location.startsWith('/work/salon') ||
        location.startsWith('/work/team') ||
        location.startsWith('/work/qr')) {
      return 3;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexForLocation(location);
    final membership = ref.watch(membershipProvider).value;
    final isOwner = membership?.isOwner == true;
    final scheduleNeedsAttention =
        ref.watch(weeklyScheduleNeedsAttentionProvider).value == true;
    final workDestinations = [
      const AppBottomNavDestination(
        label: 'Inicio',
        icon: Icons.inbox_outlined,
        selectedIcon: Icons.inbox_rounded,
      ),
      const AppBottomNavDestination(
        label: 'Agenda',
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month_rounded,
      ),
      AppBottomNavDestination(
        label: 'Horario',
        icon: Icons.schedule_outlined,
        selectedIcon: Icons.schedule_rounded,
        showAttentionIndicator: scheduleNeedsAttention,
      ),
      AppBottomNavDestination(
        label: isOwner ? 'Negocio' : 'Stats',
        icon: isOwner ? Icons.storefront_outlined : Icons.bar_chart_outlined,
        selectedIcon: isOwner
            ? Icons.storefront_rounded
            : Icons.bar_chart_rounded,
      ),
    ];

    return _AppShellScaffold(
      routeKey: location,
      currentIndex: index,
      destinations: workDestinations,
      onDestinationSelected: (i) {
        switch (i) {
          case 0:
            context.go('/work');
          case 1:
            context.go('/work/calendar');
          case 2:
            context.go('/work/availability');
          case 3:
            context.go(isOwner ? '/work/salon' : '/work/stats');
        }
      },
      child: child,
    );
  }
}

/// Shell visual compartido que oculta la navegación al avanzar por contenido.
class _AppShellScaffold extends StatefulWidget {
  const _AppShellScaffold({
    required this.routeKey,
    required this.child,
    required this.currentIndex,
    required this.destinations,
    required this.onDestinationSelected,
  });

  final String routeKey;
  final Widget child;
  final int currentIndex;
  final List<AppBottomNavDestination> destinations;
  final ValueChanged<int> onDestinationSelected;

  @override
  State<_AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends State<_AppShellScaffold> {
  static const _travelThreshold = 18.0;

  bool _navigationVisible = true;
  double _accumulatedTravel = 0;

  @override
  void didUpdateWidget(_AppShellScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeKey != widget.routeKey) {
      _navigationVisible = true;
      _accumulatedTravel = 0;
    }
  }

  void _setNavigationVisible(bool visible) {
    if (_navigationVisible == visible) return;
    setState(() => _navigationVisible = visible);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical ||
        notification.metrics.outOfRange) {
      return false;
    }

    if (notification.metrics.extentBefore <= 2) {
      _accumulatedTravel = 0;
      _setNavigationVisible(true);
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (delta == 0) return false;

      if ((_accumulatedTravel > 0 && delta < 0) ||
          (_accumulatedTravel < 0 && delta > 0)) {
        _accumulatedTravel = 0;
      }
      _accumulatedTravel += delta;

      if (_accumulatedTravel >= _travelThreshold) {
        _accumulatedTravel = 0;
        _setNavigationVisible(false);
      } else if (_accumulatedTravel <= -_travelThreshold) {
        _accumulatedTravel = 0;
        _setNavigationVisible(true);
      }
    } else if (notification is ScrollEndNotification) {
      _accumulatedTravel = 0;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final visible = _navigationVisible && !keyboardVisible;
    final duration = AppMotion.durationOf(context, AppMotion.normal);
    final curve = AppMotion.curveOf(context, AppMotion.decelerate);

    return Scaffold(
      extendBody: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      ),
      bottomNavigationBar: IgnorePointer(
        ignoring: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: AnimatedSlide(
            offset: visible ? Offset.zero : const Offset(0, 1),
            duration: duration,
            curve: curve,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: duration,
              curve: curve,
              child: AppBottomNavBarWidget(
                currentIndex: widget.currentIndex,
                destinations: widget.destinations,
                onDestinationSelected: widget.onDestinationSelected,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
