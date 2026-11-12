import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/features/salon/domain/entities/salon_membership_entity.dart';
import 'package:jolom/features/salon/presentation/widgets/share_salon_cta_widget.dart';

void main() {
  testWidgets('abre el modal para compartir la peluquería activa', (
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
          home: const Scaffold(body: ShareSalonCtaWidget()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Invita a tus amigos y clientes'), findsOneWidget);
    expect(find.textContaining('te encuentren en Jolom'), findsOneWidget);

    await tester.tap(find.text('Compartir mi negocio'));
    await tester.pumpAndSettle();

    expect(find.text('Compartir local'), findsOneWidget);
    expect(find.text('https://jolom.example/s/salon-1'), findsOneWidget);
  });
}
