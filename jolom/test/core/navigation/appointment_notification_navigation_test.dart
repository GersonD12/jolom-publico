import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/app/routes/routes.dart';
import 'package:jolom/core/navigation/work_appointment_nav.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/providers/session_provider.dart';
import 'package:jolom/features/notification/domain/entities/app_notification_entity.dart';
import 'package:jolom/features/notification/domain/entities/appointment_notification_payload.dart';
import 'package:jolom/features/notification/presentation/screens/notifications_screen.dart';
import 'package:jolom/features/salon/domain/entities/salon_membership_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OpenNotificationButton extends ConsumerWidget {
  const _OpenNotificationButton({required this.openMode});

  final AppointmentNotificationOpenMode openMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () =>
          openAppointmentFromNotification(ref, 'appointment-1', openMode),
      child: const Text('Abrir'),
    );
  }
}

void main() {
  Future<(ProviderContainer, GoRouter)> pumpNavigation(
    WidgetTester tester,
    AppointmentNotificationOpenMode openMode,
    Stream<SalonMembership?> membershipStream,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              Scaffold(body: _OpenNotificationButton(openMode: openMode)),
        ),
        GoRoute(
          path: '/appointments',
          builder: (_, _) => const Scaffold(body: Text('Cliente')),
        ),
        GoRoute(
          path: '/work',
          builder: (_, _) => const Scaffold(body: Text('Trabajo')),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        goRouterProvider.overrideWithValue(router),
        membershipProvider.overrideWith((_) => membershipStream),
      ],
    );
    addTearDown(() {
      container.dispose();
      router.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return (container, router);
  }

  testWidgets('client abre citas y resalta la cita aunque haya membresía', (
    tester,
  ) async {
    final (container, _) = await pumpNavigation(
      tester,
      AppointmentNotificationOpenMode.client,
      Stream.value(
        const SalonMembership(
          userId: 'user-1',
          salonId: 'salon-1',
          role: MembershipRole.owner,
          status: MembershipStatus.active,
        ),
      ),
    );

    expect(find.text('Cliente'), findsOneWidget);
    expect(container.read(appModeProvider), AppMode.client);
    expect(
      container.read(highlightedClientAppointmentIdProvider),
      'appointment-1',
    );
  });

  testWidgets('work abre trabajo aunque membershipProvider siga cargando', (
    tester,
  ) async {
    final (container, _) = await pumpNavigation(
      tester,
      AppointmentNotificationOpenMode.work,
      const Stream.empty(),
    );

    expect(find.text('Trabajo'), findsOneWidget);
    expect(container.read(appModeProvider), AppMode.work);
    expect(container.read(highlightedAppointmentIdProvider), 'appointment-1');
    expect(container.read(membershipProvider).isLoading, isTrue);
  });

  testWidgets('la bandeja interna respeta openMode', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final notification = AppNotification(
      id: 'notification-1',
      type: AppointmentNotificationPayload.type,
      title: 'Cita confirmada',
      body: 'Contenido',
      data: const AppointmentNotificationPayload(
        appointmentId: 'appointment-2',
        openMode: AppointmentNotificationOpenMode.work,
        kind: AppointmentNotificationKind.statusChange,
      ).toData(),
      createdAt: DateTime(2026),
      readAt: DateTime(2026),
    );
    final router = GoRouter(
      initialLocation: '/notifications',
      routes: [
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/work',
          builder: (_, _) =>
              const Scaffold(body: Text('Trabajo desde bandeja')),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        goRouterProvider.overrideWithValue(router),
        sessionProvider.overrideWith((_) => Stream.value(null)),
        notificationsProvider.overrideWith((_) => Stream.value([notification])),
        pendingInvitationsProvider.overrideWith((_) async => const []),
      ],
    );
    addTearDown(() {
      container.dispose();
      router.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cita confirmada'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Trabajo desde bandeja'), findsOneWidget);
    expect(container.read(appModeProvider), AppMode.work);
    expect(container.read(highlightedAppointmentIdProvider), 'appointment-2');
  });
}
