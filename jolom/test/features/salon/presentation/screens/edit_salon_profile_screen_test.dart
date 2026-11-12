import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/features/salon/domain/entities/salon_entity.dart';
import 'package:jolom/features/salon/domain/repositories/salon_repository.dart';
import 'package:jolom/features/salon/presentation/screens/edit_salon_profile_screen.dart';

void main() {
  late _SalonRepository repository;

  setUp(() async {
    await getIt.reset();
    repository = _SalonRepository();
    getIt.registerSingleton<SalonRepository>(repository);
  });

  tearDown(() => getIt.reset());

  testWidgets('impide guardar el perfil sin ninguna foto', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const EditSalonProfileScreen(salonId: 'salon-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(
      find.text('Conserva al menos una foto del negocio.'),
      findsOneWidget,
    );

    final saveButton = find.text('Guardar');
    await tester.scrollUntilVisible(
      saveButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveButton);
    await tester.pump();

    expect(repository.updated, isFalse);
    expect(find.byType(EditSalonProfileScreen), findsOneWidget);
  });
}

class _SalonRepository implements SalonRepository {
  bool updated = false;

  @override
  Future<Salon?> getSalon(String salonId) async => const Salon(
    id: 'salon-1',
    ownerId: 'owner-1',
    name: 'Peluquería Prueba',
    city: 'Guatemala',
    currency: 'GTQ',
    timeZone: 'America/Guatemala',
    publishStatus: SalonPublishStatus.published,
    contactPhone: '5555-5555',
    address: 'Zona 1',
    imageUrls: ['https://example.com/place.webp'],
    latitude: 14.6349,
    longitude: -90.5069,
  );

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
