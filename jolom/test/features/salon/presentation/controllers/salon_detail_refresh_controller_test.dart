import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/features/salon/presentation/controllers/salon_detail_refresh_controller.dart';

void main() {
  test('comparte la primera recarga mientras está en curso', () async {
    final controller = SalonDetailRefreshController();
    final completer = Completer<void>();
    var calls = 0;

    Future<void> refresh() {
      calls++;
      return completer.future;
    }

    final first = controller.run(refresh);
    final second = controller.run(refresh);

    expect(calls, 1);
    completer.complete();
    await Future.wait([first, second]);
  });

  test('respeta el intervalo y permite recargar después', () async {
    var now = DateTime(2026, 8, 18, 12);
    final controller = SalonDetailRefreshController(clock: () => now);
    var calls = 0;

    Future<void> refresh() async => calls++;

    await controller.run(refresh);
    await controller.run(refresh);
    expect(calls, 1);

    now = now.add(const Duration(seconds: 5));
    await controller.run(refresh);
    expect(calls, 2);
  });
}
