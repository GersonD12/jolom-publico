import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/features/salon/presentation/widgets/salon_map_controls_widget.dart';

void main() {
  testWidgets('muestra solo la acción de ubicación', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SalonMapControlsWidget(
            locating: false,
            onUseCurrentLocation: () {},
          ),
        ),
      ),
    );

    expect(find.byTooltip('Mi ubicación'), findsOneWidget);
    expect(find.byType(DropdownButton<double>), findsNothing);
    expect(find.text('Radio 10 km'), findsNothing);
    expect(find.text('Buscar aquí'), findsNothing);
  });
}
