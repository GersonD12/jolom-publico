import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';
import 'package:jolom/features/shell/presentation/screens/shell_screens.dart';
import 'package:jolom/shared/widgets/app_bottom_nav_bar_widget.dart';

void main() {
  testWidgets('comunica el espacio del menú a overlays de pantallas hijas', (
    tester,
  ) async {
    var overlayInset = 0.0;
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (context, state, child) => ClientShellScreen(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => Scaffold(
                body: Builder(
                  builder: (context) {
                    overlayInset = appBottomOverlayInset(context);
                    return const SizedBox();
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(overlayInset, greaterThan(AppSpacing.md));
  });

  testWidgets('oculta el menú al bajar y lo muestra al subir', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (context, state, child) => ClientShellScreen(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => Scaffold(
                body: ListView.builder(
                  key: const ValueKey('scrollable'),
                  itemExtent: 80,
                  itemCount: 30,
                  itemBuilder: (_, index) => Text('Elemento $index'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    AnimatedSlide navigationSlide() =>
        tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));

    expect(navigationSlide().offset, Offset.zero);

    await tester.drag(
      find.byKey(const ValueKey('scrollable')),
      const Offset(0, -180),
    );
    await tester.pump();
    expect(navigationSlide().offset, const Offset(0, 1));

    await tester.drag(
      find.byKey(const ValueKey('scrollable')),
      const Offset(0, 180),
    );
    await tester.pump();
    expect(navigationSlide().offset, Offset.zero);
  });

  testWidgets('edición del negocio se abre fuera del shell', (tester) async {
    final router = GoRouter(
      initialLocation: '/work/salon',
      routes: [
        ShellRoute(
          builder: (context, state, child) => WorkShellScreen(child: child),
          routes: [
            GoRoute(
              path: '/work/salon',
              builder: (_, _) => const Scaffold(body: Text('Negocio')),
            ),
          ],
        ),
        GoRoute(
          path: '/work/salon/edit',
          builder: (_, _) => const Scaffold(body: Text('Editar perfil')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membershipProvider.overrideWith((_) => Stream.value(null)),
          weeklyScheduleNeedsAttentionProvider.overrideWith(
            (_) => Stream.value(true),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomNavBarWidget), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-attention-Horario')), findsOneWidget);

    router.push('/work/salon/edit');
    await tester.pumpAndSettle();

    expect(find.byType(AppBottomNavBarWidget), findsNothing);
    expect(find.text('Editar perfil'), findsOneWidget);
  });
}
