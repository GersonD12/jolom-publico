import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/features/salon/domain/entities/salon_entity.dart';
import 'package:jolom/features/salon/presentation/screens/salon_detail_screen.dart';

void main() {
  testWidgets('permite deslizar y limita recargas consecutivas', (
    tester,
  ) async {
    var detailLoads = 0;
    var serviceLoads = 0;
    var hoursLoads = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salonDetailProvider.overrideWith((ref, salonId) async {
            detailLoads++;
            return _salon;
          }),
          salonServicesProvider.overrideWith((ref, salonId) async {
            serviceLoads++;
            return const [];
          }),
          salonOwnerWeeklyHoursProvider.overrideWith((ref, salonId) async {
            hoursLoads++;
            return const {};
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SalonDetailScreen(salonId: 'salon-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(detailLoads, 1);

    await tester.drag(find.byType(ListView), const Offset(0, 320));
    await tester.pumpAndSettle();
    expect(detailLoads, 2);
    expect(serviceLoads, 2);
    expect(hoursLoads, 2);

    await tester.drag(find.byType(ListView), const Offset(0, 320));
    await tester.pumpAndSettle();
    expect(detailLoads, 2);
    expect(serviceLoads, 2);
    expect(hoursLoads, 2);
  });
}

const _salon = Salon(
  id: 'salon-1',
  ownerId: 'owner-1',
  name: 'Negocio de prueba',
  city: 'Guatemala',
  currency: 'GTQ',
  timeZone: 'America/Guatemala',
  publishStatus: SalonPublishStatus.published,
);
