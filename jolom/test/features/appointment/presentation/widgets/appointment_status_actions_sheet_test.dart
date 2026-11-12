import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/features/appointment/domain/entities/appointment_entity.dart';
import 'package:jolom/features/appointment/presentation/widgets/appointment_status_actions_sheet.dart';

void main() {
  const cases = [
    (
      status: AppointmentStatus.confirmed,
      title: 'Aprobar solicitud',
      actionLabel: 'Sí, aprobar',
    ),
    (
      status: AppointmentStatus.rejected,
      title: 'Rechazar solicitud',
      actionLabel: 'Sí, rechazar',
    ),
    (
      status: AppointmentStatus.cancelledByClient,
      title: 'Cancelar cita',
      actionLabel: 'Sí, cancelar',
    ),
    (
      status: AppointmentStatus.cancelledByBusiness,
      title: 'Cancelar cita',
      actionLabel: 'Sí, cancelar',
    ),
    (
      status: AppointmentStatus.completed,
      title: 'Finalizar cita',
      actionLabel: 'Sí, finalizar',
    ),
    (
      status: AppointmentStatus.noShow,
      title: 'Marcar inasistencia',
      actionLabel: 'Sí, no asistió',
    ),
  ];

  for (final testCase in cases) {
    testWidgets('confirma la acción ${testCase.status.name}', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await confirmAppointmentStatusAction(
                    context,
                    testCase.status,
                  );
                },
                child: const Text('Cambiar estado'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Cambiar estado'));
      await tester.pumpAndSettle();

      expect(find.text(testCase.title), findsOneWidget);
      expect(find.text(testCase.actionLabel), findsOneWidget);

      await tester.tap(find.text(testCase.actionLabel));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  }

  testWidgets('no aprueba la solicitud cuando se cierra el diálogo', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await confirmAppointmentStatusAction(
                  context,
                  AppointmentStatus.confirmed,
                );
              },
              child: const Text('Cambiar estado'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Cambiar estado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
