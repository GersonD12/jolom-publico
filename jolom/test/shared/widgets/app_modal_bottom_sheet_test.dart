import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/shared/widgets/app_modal_bottom_sheet.dart';

void main() {
  testWidgets('abre la hoja en el navegador raíz', (tester) async {
    final rootNavigatorKey = GlobalKey<NavigatorState>();
    final nestedNavigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: Navigator(
          key: nestedNavigatorKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showAppModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const Text('Contenido modal'),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    final sheetContext = tester.element(find.text('Contenido modal'));
    expect(Navigator.of(sheetContext), rootNavigatorKey.currentState);
    expect(Navigator.of(sheetContext), isNot(nestedNavigatorKey.currentState));
  });
}
