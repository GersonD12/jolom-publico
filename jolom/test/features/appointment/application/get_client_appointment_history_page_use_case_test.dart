import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/features/appointment/application/use_cases/get_client_appointment_history_page_use_case.dart';
import 'package:jolom/features/appointment/domain/entities/appointment_history_cursor_entity.dart';
import 'package:jolom/features/appointment/domain/entities/appointment_history_page_entity.dart';
import 'package:jolom/features/appointment/domain/repositories/appointment_repository.dart';

void main() {
  group('GetClientAppointmentHistoryPageUseCase', () {
    test('rechaza límites no positivos', () {
      final useCase = GetClientAppointmentHistoryPageUseCase(
        _FakeAppointmentRepository(),
      );

      expect(
        () => useCase(clientId: 'client-1', limit: 0),
        throwsArgumentError,
      );
    });

    test('envía cliente, cursor y límite al repositorio', () async {
      final repository = _FakeAppointmentRepository();
      final useCase = GetClientAppointmentHistoryPageUseCase(repository);
      final cursor = AppointmentHistoryCursor(
        startAt: DateTime.utc(2026, 8, 5),
        appointmentId: 'appointment-7',
      );

      final result = await useCase(
        clientId: 'client-1',
        cursor: cursor,
        limit: 7,
      );

      expect(result, same(repository.response));
      expect(repository.clientId, 'client-1');
      expect(repository.cursor, same(cursor));
      expect(repository.limit, 7);
    });
  });
}

class _FakeAppointmentRepository implements AppointmentRepository {
  final response = const AppointmentHistoryPage.empty();
  String? clientId;
  AppointmentHistoryCursor? cursor;
  int? limit;

  @override
  Future<AppointmentHistoryPage> getClientAppointmentHistoryPage({
    required String clientId,
    AppointmentHistoryCursor? cursor,
    int limit = 7,
  }) async {
    this.clientId = clientId;
    this.cursor = cursor;
    this.limit = limit;
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
