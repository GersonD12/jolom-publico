import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/features/appointment/application/use_cases/get_barber_appointments_page_use_case.dart';
import 'package:jolom/features/appointment/domain/entities/work_calendar_cursor_entity.dart';
import 'package:jolom/features/appointment/domain/entities/work_calendar_page_entity.dart';
import 'package:jolom/features/appointment/domain/repositories/appointment_repository.dart';

void main() {
  group('GetBarberAppointmentsPageUseCase', () {
    test('rechaza peluquero vacío y límites no positivos', () {
      final useCase = GetBarberAppointmentsPageUseCase(
        _FakeAppointmentRepository(),
      );

      expect(() => useCase(barberId: ''), throwsArgumentError);
      expect(
        () => useCase(barberId: 'barber-1', limit: 0),
        throwsArgumentError,
      );
    });

    test('envía peluquero, cursor y límite al repositorio', () async {
      final repository = _FakeAppointmentRepository();
      final useCase = GetBarberAppointmentsPageUseCase(repository);
      final cursor = WorkCalendarCursor(
        startAt: DateTime.utc(2026, 8, 5),
        appointmentId: 'appointment-7',
      );

      final result = await useCase(
        barberId: 'barber-1',
        cursor: cursor,
        limit: 20,
      );

      expect(result, same(repository.response));
      expect(repository.barberId, 'barber-1');
      expect(repository.cursor, same(cursor));
      expect(repository.limit, 20);
    });
  });
}

class _FakeAppointmentRepository implements AppointmentRepository {
  final response = const WorkCalendarPage.empty();
  String? barberId;
  WorkCalendarCursor? cursor;
  int? limit;

  @override
  Future<WorkCalendarPage> getBarberAppointmentsPage({
    required String barberId,
    WorkCalendarCursor? cursor,
    int limit = 20,
  }) async {
    this.barberId = barberId;
    this.cursor = cursor;
    this.limit = limit;
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
