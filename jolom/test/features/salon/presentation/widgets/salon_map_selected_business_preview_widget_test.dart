import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/features/salon/domain/entities/nearby_salon_entity.dart';
import 'package:jolom/features/salon/domain/entities/salon_entity.dart';
import 'package:jolom/features/salon/presentation/widgets/salon_map_selected_business_preview_widget.dart';

void main() {
  testWidgets('muestra los datos cargados y conserva acciones independientes', (
    tester,
  ) async {
    var opened = false;
    var closed = false;
    final item = NearbySalon(
      salon: const Salon(
        id: 'salon-1',
        ownerId: 'owner',
        name: 'Corte Central',
        address: 'Zona 1',
        city: 'Guatemala',
        currency: 'GTQ',
        timeZone: 'America/Guatemala',
        publishStatus: SalonPublishStatus.published,
      ),
      distanceKm: 0.8,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            child: SizedBox(
              width: 320,
              child: SalonMapSelectedBusinessPreviewWidget(
                item: item,
                onClose: () => closed = true,
                onOpen: () => opened = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Corte Central'), findsOneWidget);
    expect(find.text('800 m · Zona 1'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Corte Central'));
    expect(opened, isTrue);
    expect(closed, isFalse);

    await tester.tap(find.byTooltip('Cerrar negocio seleccionado'));
    expect(closed, isTrue);
  });

  testWidgets('permite recorrer todas las imágenes disponibles', (
    tester,
  ) async {
    var opened = false;
    final item = NearbySalon(
      salon: const Salon(
        id: 'salon-1',
        ownerId: 'owner',
        name: 'Corte Central',
        city: 'Guatemala',
        currency: 'GTQ',
        timeZone: 'America/Guatemala',
        publishStatus: SalonPublishStatus.published,
        imageUrls: [
          'https://example.com/salon-1.webp',
          'https://example.com/salon-2.webp',
        ],
      ),
      distanceKm: 0.8,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            child: SizedBox(
              width: 320,
              child: SalonMapSelectedBusinessPreviewWidget(
                item: item,
                onClose: () {},
                onOpen: () => opened = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('1 / 2'), findsNothing);
    expect(
      find.byKey(const ValueKey('gallery-dot-0-selected')),
      findsOneWidget,
    );

    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('gallery-dot-1-selected')),
      findsOneWidget,
    );
    expect(opened, isFalse);
  });
}
