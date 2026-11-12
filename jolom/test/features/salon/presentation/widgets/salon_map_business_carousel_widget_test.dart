import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/features/salon/domain/entities/nearby_salon_entity.dart';
import 'package:jolom/features/salon/domain/entities/salon_entity.dart';
import 'package:jolom/features/salon/presentation/widgets/salon_map_business_card_widget.dart';
import 'package:jolom/features/salon/presentation/widgets/salon_map_business_carousel_widget.dart';

void main() {
  testWidgets('muestra negocios sin cerrar y abre el negocio tocado', (
    tester,
  ) async {
    final first = NearbySalon(
      salon: _salon(id: 'salon-1', name: 'Corte Central'),
      distanceKm: 0.8,
    );
    final second = NearbySalon(
      salon: _salon(id: 'salon-2', name: 'Estudio Norte'),
      distanceKm: 2.1,
    );
    NearbySalon? highlighted;
    NearbySalon? opened;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SalonMapBusinessCarouselWidget(
              items: [first, second],
              onHighlight: (item) => highlighted = item,
              onOpen: (item) => opened = item,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('nearby-salons-carousel')),
      findsOneWidget,
    );
    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.controller?.viewportFraction, 1);
    expect(pageView.clipBehavior, Clip.hardEdge);
    expect(find.text('Corte Central'), findsOneWidget);
    expect(find.byTooltip('Cerrar'), findsNothing);

    await tester.tap(find.text('Corte Central'));
    expect(highlighted, same(first));
    expect(opened, isNull);

    final firstCard = find.byKey(const ValueKey('nearby-salon-salon-1'));
    await tester.tap(
      find.descendant(of: firstCard, matching: find.byTooltip('Ver negocio')),
    );
    expect(opened, same(first));
  });

  testWidgets('avanza automáticamente y vuelve al inicio en bucle', (
    tester,
  ) async {
    final first = NearbySalon(
      salon: _salon(id: 'salon-1', name: 'Corte Central'),
      distanceKm: 0.8,
    );
    final second = NearbySalon(
      salon: _salon(id: 'salon-2', name: 'Estudio Norte'),
      distanceKm: 2.1,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SalonMapBusinessCarouselWidget(
            items: [first, second],
            onHighlight: (_) {},
            onOpen: (_) {},
          ),
        ),
      ),
    );

    PageController controller() =>
        tester.widget<PageView>(find.byType(PageView)).controller!;
    expect(controller().page, 1);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(controller().page, 2);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(controller().page, 1);
  });

  testWidgets('muestra la tarjeta seleccionada sin una altura exterior', (
    tester,
  ) async {
    final selected = NearbySalon(
      salon: _salon(id: 'salon-1', name: 'Corte Central'),
      distanceKm: 0.8,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SalonMapBusinessCardWidget(
              item: selected,
              onClose: () {},
              onOpen: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Corte Central'), findsOneWidget);
    expect(find.byTooltip('Cerrar'), findsOneWidget);
    expect(find.byTooltip('Ver negocio'), findsOneWidget);
  });
}

Salon _salon({required String id, required String name}) => Salon(
  id: id,
  ownerId: 'owner',
  name: name,
  address: 'Zona 1',
  city: 'Guatemala',
  currency: 'GTQ',
  timeZone: 'America/Guatemala',
  publishStatus: SalonPublishStatus.published,
);
