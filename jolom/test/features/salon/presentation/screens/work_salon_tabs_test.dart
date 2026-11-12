import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/features/salon/domain/entities/salon_entity.dart';
import 'package:jolom/features/salon/domain/entities/salon_membership_entity.dart';
import 'package:jolom/features/salon/domain/entities/service_entity.dart';
import 'package:jolom/features/salon/domain/repositories/salon_repository.dart';
import 'package:jolom/features/salon/presentation/screens/work_salon_screen.dart';

void main() {
  late _SalonRepository repository;

  setUp(() async {
    await getIt.reset();
    repository = _SalonRepository();
    getIt.registerSingleton<SalonRepository>(repository);
  });

  tearDown(() => getIt.reset());

  testWidgets('separa perfil y servicios e indica cuando no hay servicios', (
    tester,
  ) async {
    const membership = SalonMembership(
      userId: 'owner-1',
      salonId: 'salon-1',
      role: MembershipRole.owner,
      status: MembershipStatus.active,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membershipProvider.overrideWithValue(const AsyncData(membership)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const WorkSalonScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Servicios'), findsOneWidget);
    expect(find.byKey(const ValueKey('salon-settings-button')), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart), findsNothing);
    expect(find.byKey(const ValueKey('hide-salon-button')), findsOneWidget);
    expect(find.text('Ocultar'), findsNothing);
    expect(
      find.byKey(const ValueKey('missing-services-indicator')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('salon-qr-button')));
    await tester.pumpAndSettle();

    expect(find.text('Compartir local'), findsOneWidget);
    expect(find.text('https://jolom.example/s/salon-1'), findsOneWidget);
    Navigator.of(tester.element(find.text('Compartir local'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Servicios'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('empty-services-notice')), findsOneWidget);
    expect(find.text('Aún no tienes servicios'), findsOneWidget);
    expect(find.text('Agregar primer servicio'), findsOneWidget);
  });

  testWidgets('abre el formulario en un modal cuando ya existen servicios', (
    tester,
  ) async {
    repository.services = const [
      Service(
        id: 'service-1',
        salonId: 'salon-1',
        name: 'Corte',
        durationMinutes: 30,
        price: 50,
        currency: 'GTQ',
        enabledBarberIds: [],
        status: 'active',
      ),
    ];

    const membership = SalonMembership(
      userId: 'owner-1',
      salonId: 'salon-1',
      role: MembershipRole.owner,
      status: MembershipStatus.active,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membershipProvider.overrideWithValue(const AsyncData(membership)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const WorkSalonScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Servicios'));
    await tester.pumpAndSettle();

    expect(find.text('Corte'), findsOneWidget);
    expect(find.text('Agregar primer servicio'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('add-service-button')));
    await tester.pumpAndSettle();

    expect(find.text('Agregar servicio'), findsNWidgets(2));
    final fields = find.byType(TextFormField);
    await tester.tap(fields.at(2));
    await tester.pumpAndSettle();
    final priceEditable = tester.widget<EditableText>(
      find.descendant(of: fields.at(2), matching: find.byType(EditableText)),
    );
    expect(priceEditable.focusNode.hasFocus, isTrue);
    expect(find.text('Listo'), findsNothing);
    await tester.tap(find.text('Agregar servicio').first);
    await tester.pumpAndSettle();
    expect(priceEditable.focusNode.hasFocus, isFalse);

    await tester.enterText(fields.at(0), 'Barba');
    await tester.tap(find.text('Agregar servicio').last);
    await tester.pumpAndSettle();

    expect(repository.createdServiceName, 'Barba');
    expect(find.text('Barba'), findsOneWidget);
  });

  testWidgets('oculta el botón publicar cuando la peluquería está publicada', (
    tester,
  ) async {
    repository.publishStatus = SalonPublishStatus.published;
    repository.services = const [
      Service(
        id: 'service-1',
        salonId: 'salon-1',
        name: 'Corte',
        durationMinutes: 30,
        price: 50,
        currency: 'GTQ',
        enabledBarberIds: [],
        status: 'active',
      ),
    ];
    const membership = SalonMembership(
      userId: 'owner-1',
      salonId: 'salon-1',
      role: MembershipRole.owner,
      status: MembershipStatus.active,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membershipProvider.overrideWithValue(const AsyncData(membership)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const WorkSalonScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Editar perfil'),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Editar perfil'), findsOneWidget);
    expect(find.text('Publicar'), findsNothing);
  });
}

class _SalonRepository implements SalonRepository {
  List<Service> services = [];
  String? createdServiceName;
  SalonPublishStatus publishStatus = SalonPublishStatus.draft;

  @override
  Future<Salon?> getSalon(String salonId) async => Salon(
    id: 'salon-1',
    ownerId: 'owner-1',
    name: 'Peluquería Prueba',
    city: 'Guatemala',
    currency: 'GTQ',
    timeZone: 'America/Guatemala',
    publishStatus: publishStatus,
  );

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
    services = [
      ...services,
      Service(
        id: 'service-${services.length + 1}',
        salonId: salonId,
        name: name,
        durationMinutes: durationMinutes,
        price: price,
        currency: 'GTQ',
        enabledBarberIds: const [],
        status: 'active',
      ),
    ];
    return services.last.id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
