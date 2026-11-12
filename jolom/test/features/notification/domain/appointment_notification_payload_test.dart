import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/features/appointment/domain/entities/appointment_entity.dart';
import 'package:jolom/features/notification/domain/entities/appointment_notification_payload.dart';

void main() {
  const payload = AppointmentNotificationPayload(
    appointmentId: 'appointment-1',
    openMode: AppointmentNotificationOpenMode.client,
    kind: AppointmentNotificationKind.statusChange,
    status: AppointmentStatus.confirmed,
  );

  test('el payload local conserva appointmentId y openMode', () {
    final parsed =
        AppointmentNotificationPayload.tryParseLocalNotificationPayload(
          payload.toLocalNotificationPayload(),
        );

    expect(parsed?.appointmentId, 'appointment-1');
    expect(parsed?.openMode, AppointmentNotificationOpenMode.client);
    expect(parsed?.kind, AppointmentNotificationKind.statusChange);
    expect(parsed?.status, AppointmentStatus.confirmed);
  });

  test('rechaza un openMode inválido', () {
    final parsed = AppointmentNotificationPayload.tryParse({
      ...payload.toData(),
      'openMode': 'unknown',
    });

    expect(parsed, isNull);
  });

  test('rechaza un payload sin appointmentId', () {
    final data = payload.toData()..remove('appointmentId');

    expect(AppointmentNotificationPayload.tryParse(data), isNull);
  });
}
