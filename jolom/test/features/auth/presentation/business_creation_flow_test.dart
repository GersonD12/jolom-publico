import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/providers/app_config_provider.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/features/appointment/domain/entities/availability_entity.dart';
import 'package:jolom/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:jolom/features/auth/presentation/screens/business_screen.dart';
import 'package:jolom/features/salon/domain/entities/salon_entity.dart';
import 'package:jolom/features/salon/domain/entities/service_entity.dart';
import 'package:jolom/features/salon/domain/repositories/salon_repository.dart';
import 'package:jolom/features/salon/presentation/screens/complete_salon_setup_screen.dart';
import 'package:jolom/features/salon/presentation/screens/configure_initial_schedule_screen.dart';
import 'package:jolom/features/salon/presentation/screens/create_first_service_screen.dart';

void main() {
  late _FakeSalonRepository salonRepository;
  late _FakeAppointmentRepository appointmentRepository;

  setUp(() async {
    await getIt.reset();
    salonRepository = _FakeSalonRepository();
    appointmentRepository = _FakeAppointmentRepository();
    getIt.registerSingleton<SalonRepository>(salonRepository);
    getIt.registerSingleton<AppointmentRepository>(appointmentRepository);
  });

  tearDown(() => getIt.reset());

  testWidgets('completa perfil, crea servicio, configura horario y publica', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/profile/business',
      routes: [
        GoRoute(
          path: '/profile/business',
          builder: (_, _) => const BusinessScreen(),
        ),
        ..._onboardingRoutes(),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membershipProvider.overrideWith((_) => Stream.value(null)),
          canCreateSalonProvider.overrideWith((_) => Stream.value(true)),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear mi peluquería'));
    await tester.pumpAndSettle();

    expect(_filledButton(tester, 'Crear mi peluquería').onPressed, isNull);
    var fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Peluquería Prueba');
    await tester.enterText(fields.at(1), '5555-5555');
    await tester.enterText(fields.at(2), 'Zona 1');
    expect(_filledButton(tester, 'Crear mi peluquería').onPressed, isNotNull);
    await tester.tap(find.text('Crear mi peluquería').last);
    await tester.pumpAndSettle();

    expect(find.byType(CompleteSalonSetupScreen), findsOneWidget);
    expect(find.text('PASO 1 DE 3'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(salonRepository.createdName, 'Peluquería Prueba');

    expect(_filledButton(tester, 'Continuar al servicio').onPressed, isNotNull);
    await tester.tap(find.text('Continuar al servicio'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateFirstServiceScreen), findsOneWidget);
    expect(find.text('PASO 2 DE 3'), findsOneWidget);
    expect(_filledButton(tester, 'Guardar y continuar').onPressed, isNull);
    fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Corte clásico');
    await tester.enterText(fields.at(1), '45');
    await tester.enterText(fields.at(2), '75');
    expect(_filledButton(tester, 'Guardar y continuar').onPressed, isNotNull);
    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar y continuar'));
    await tester.pumpAndSettle();

    expect(salonRepository.createdServiceName, 'Corte clásico');
    expect(find.byType(ConfigureInitialScheduleScreen), findsOneWidget);
    expect(find.text('PASO 3 DE 3'), findsOneWidget);

    expect(_filledButton(tester, 'Guardar y publicar').onPressed, isNotNull);
    await tester.tap(find.text('Guardar y publicar'));
    await tester.pumpAndSettle();

    expect(appointmentRepository.savedWeeklyHours, isNotNull);
    expect(appointmentRepository.savedWeeklyHours!['mon'], {
      'start': '09:00',
      'end': '18:00',
    });
    expect(appointmentRepository.savedWeeklyHours!['sat'], isNull);
    expect(appointmentRepository.savedWeeklyHours!['sun'], {
      'start': '09:00',
      'end': '18:00',
    });
    expect(salonRepository.publishedStatus, SalonPublishStatus.published);
    expect(find.text('Gestión actual'), findsOneWidget);
  });

  testWidgets('impide guardar el perfil sin un punto en el mapa', (
    tester,
  ) async {
    salonRepository.hasLocation = false;
    final router = GoRouter(
      initialLocation: '/onboarding/salon/setup?salonId=salon-1',
      routes: _onboardingRoutes(),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [membershipProvider.overrideWith((_) => Stream.value(null))],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(_filledButton(tester, 'Continuar al servicio').onPressed, isNull);
    expect(salonRepository.updated, isFalse);
    expect(find.byType(CompleteSalonSetupScreen), findsOneWidget);
  });

  testWidgets('impide completar el perfil inicial sin una foto', (
    tester,
  ) async {
    salonRepository.hasImage = false;
    final router = GoRouter(
      initialLocation: '/onboarding/salon/setup?salonId=salon-1',
      routes: _onboardingRoutes(),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [membershipProvider.overrideWith((_) => Stream.value(null))],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(_filledButton(tester, 'Continuar al servicio').onPressed, isNull);
    expect(salonRepository.updated, isFalse);
    expect(find.byType(CompleteSalonSetupScreen), findsOneWidget);
  });

  testWidgets('deshabilita continuar mientras falta el nombre del servicio', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/onboarding/salon/service?salonId=salon-1',
      routes: _onboardingRoutes(),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(_filledButton(tester, 'Guardar y continuar').onPressed, isNull);
    expect(salonRepository.createdServiceName, isNull);
    expect(find.byType(CreateFirstServiceScreen), findsOneWidget);
  });

  testWidgets('cierra el teclado numérico al arrastrar la pantalla', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/onboarding/salon/service?salonId=salon-1',
      routes: _onboardingRoutes(),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final priceField = find.byType(TextFormField).at(2);
    await tester.tap(priceField);
    await tester.pumpAndSettle();

    expect(find.text('Listo'), findsNothing);
    final priceEditable = tester.widget<EditableText>(
      find.descendant(of: priceField, matching: find.byType(EditableText)),
    );
    expect(priceEditable.focusNode.hasFocus, isTrue);

    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();

    expect(priceEditable.focusNode.hasFocus, isFalse);
  });

  testWidgets('exige al menos un día abierto antes de publicar', (
    tester,
  ) async {
    appointmentRepository.existingWeeklyHours = {
      'mon': {'start': '09:00', 'end': '18:00'},
    };
    final router = GoRouter(
      initialLocation: '/onboarding/salon/schedule?salonId=salon-1',
      routes: _onboardingRoutes(),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(
      find.text('Activa al menos un día para poder publicar tu negocio.'),
      findsOneWidget,
    );
    expect(_filledButton(tester, 'Guardar y publicar').onPressed, isNull);
    expect(appointmentRepository.savedWeeklyHours, isNull);
    expect(salonRepository.publishedStatus, isNull);
  });
}

FilledButton _filledButton(WidgetTester tester, String label) {
  final finder = find.ancestor(
    of: find.text(label),
    matching: find.byType(FilledButton),
  );
  return tester.widget<FilledButton>(finder.last);
}

List<RouteBase> _onboardingRoutes() => [
  GoRoute(
    path: '/onboarding/salon/setup',
    builder: (_, state) => CompleteSalonSetupScreen(
      salonId: state.uri.queryParameters['salonId'] ?? '',
    ),
  ),
  GoRoute(
    path: '/onboarding/salon/service',
    builder: (_, state) => CreateFirstServiceScreen(
      salonId: state.uri.queryParameters['salonId'] ?? '',
    ),
  ),
  GoRoute(
    path: '/onboarding/salon/schedule',
    builder: (_, state) => ConfigureInitialScheduleScreen(
      salonId: state.uri.queryParameters['salonId'] ?? '',
      barberId: 'owner-1',
    ),
  ),
  GoRoute(
    path: '/work/salon',
    builder: (_, _) => const Scaffold(body: Text('Gestión actual')),
  ),
];

class _FakeSalonRepository implements SalonRepository {
  String? createdName;
  String? createdServiceName;
  SalonPublishStatus? publishedStatus;
  bool updated = false;
  bool hasLocation = true;
  bool hasImage = true;
  final List<Service> services = [];

  Salon get salon => Salon(
    id: 'salon-1',
    ownerId: 'owner-1',
    name: 'Peluquería Prueba',
    city: 'Guatemala',
    currency: 'GTQ',
    timeZone: 'America/Guatemala',
    publishStatus: publishedStatus ?? SalonPublishStatus.draft,
    contactPhone: '5555-5555',
    address: 'Zona 1',
    imageUrls: hasImage ? const ['https://example.com/place.webp'] : const [],
    latitude: hasLocation ? 14.6349 : null,
    longitude: hasLocation ? -90.5069 : null,
  );

  @override
  Future<Salon> createSalon({
    required String name,
    String? description,
    String? contactPhone,
    String? address,
    String? idempotencyKey,
  }) async {
    createdName = name;
    return salon;
  }

  @override
  Future<Salon?> getSalon(String salonId) async => salon;

  @override
  Future<void> updateSalon({
    required String salonId,
    String? name,
    String? description,
    String? contactPhone,
    String? address,
    String? city,
    double? latitude,
    double? longitude,
    String? coverImageUrl,
    List<String>? imageUrls,
    Map<String, dynamic>? businessHours,
    String? idempotencyKey,
  }) async {
    updated = true;
  }

  @override
  Future<List<Service>> listServices(
    String salonId, {
    bool includeInactive = false,
  }) async => services;

  @override
  Future<String> createService({
    required String salonId,
    required String name,
    required int durationMinutes,
    required double price,
    String? description,
    List<String>? enabledBarberIds,
    String? idempotencyKey,
  }) async {
    createdServiceName = name;
    services.add(
      Service(
        id: 'service-1',
        salonId: salonId,
        name: name,
        durationMinutes: durationMinutes,
        price: price,
        currency: 'GTQ',
        enabledBarberIds: const ['owner-1'],
        status: 'active',
      ),
    );
    return 'service-1';
  }

  @override
  Future<void> setSalonPublishStatus({
    required String salonId,
    required SalonPublishStatus publishStatus,
    String? idempotencyKey,
  }) async {
    publishedStatus = publishStatus;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAppointmentRepository implements AppointmentRepository {
  Map<String, dynamic> existingWeeklyHours = {};
  Map<String, dynamic>? savedWeeklyHours;

  @override
  Future<Availability?> getAvailability(String barberId) async => Availability(
    userId: barberId,
    salonId: 'salon-1',
    weeklyHours: existingWeeklyHours,
  );

  @override
  Future<void> setAvailability({
    required String barberId,
    Map<String, dynamic>? weeklyHours,
    String? idempotencyKey,
  }) async {
    savedWeeklyHours = weeklyHours;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
