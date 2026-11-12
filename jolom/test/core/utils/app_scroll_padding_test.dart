import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';

void main() {
  testWidgets('reserva el espacio comunicado por el shell', (tester) async {
    late EdgeInsets padding;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: 80),
            viewPadding: EdgeInsets.only(bottom: 24),
          ),
          child: Builder(
            builder: (context) {
              padding = appScrollPadding(context, horizontal: 16, vertical: 16);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(padding, const EdgeInsets.fromLTRB(16, 16, 16, 96));
  });

  testWidgets('posiciona overlays por encima del menú del shell', (
    tester,
  ) async {
    late double bottomInset;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: 80),
            viewPadding: EdgeInsets.only(bottom: 24),
          ),
          child: Builder(
            builder: (context) {
              bottomInset = appBottomOverlayInset(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(bottomInset, 96);
  });

  testWidgets('posiciona overlays sobre el área segura sin shell', (
    tester,
  ) async {
    late double bottomInset;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.only(bottom: 24),
          ),
          child: Builder(
            builder: (context) {
              bottomInset = appBottomOverlayInset(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(bottomInset, 40);
  });
}
