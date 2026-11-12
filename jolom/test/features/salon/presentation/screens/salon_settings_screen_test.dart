import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/features/salon/presentation/screens/salon_settings_screen.dart';

void main() {
  testWidgets('muestra estadísticas como opción y abre su vista', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/work/salon/settings',
      routes: [
        GoRoute(
          path: '/work/salon/settings',
          builder: (_, _) => const SalonSettingsScreen(),
        ),
        GoRoute(
          path: '/work/stats',
          builder: (_, _) => const Scaffold(body: Text('Vista estadísticas')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('Configuración del negocio'), findsOneWidget);
    expect(find.text('Estadísticas'), findsOneWidget);
    expect(
      find.text('Consulta el rendimiento y la actividad de tu negocio.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('salon-stats-option')));
    await tester.pumpAndSettle();

    expect(find.text('Vista estadísticas'), findsOneWidget);
  });
}
