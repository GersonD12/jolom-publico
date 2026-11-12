import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/domain/entities/user_entity.dart';
import 'package:jolom/core/providers/session_provider.dart';
import 'package:jolom/features/appointment/application/use_cases/get_barber_appointments_page_use_case.dart';
import 'package:jolom/features/appointment/domain/entities/appointment_entity.dart';
import 'package:jolom/features/appointment/domain/entities/work_calendar_cursor_entity.dart';
import 'package:jolom/features/appointment/domain/entities/work_calendar_page_entity.dart';
import 'package:jolom/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:jolom/features/appointment/presentation/providers/work_calendar_provider.dart';

void main() {
  test(
    'acumula páginas, elimina duplicados y bloquea cargas simultáneas',
    () async {
      await getIt.reset();
      final cursor = WorkCalendarCursor(
        startAt: DateTime.utc(2026, 8, 2),
        appointmentId: 'appointment-2',
      );
      final repository = _PagedAppointmentRepository([
        WorkCalendarPage(
          items: [_appointment('appointment-1'), _appointment('appointment-2')],
          hasMore: true,
          nextCursor: cursor,
        ),
        WorkCalendarPage(
          items: [_appointment('appointment-2'), _appointment('appointment-3')],
          hasMore: false,
        ),
      ]);
      getIt.registerSingleton(GetBarberAppointmentsPageUseCase(repository));
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWithValue(
            const AsyncData(UserEntity(id: 'barber-1')),
          ),
        ],
      );
      final subscription = container.listen(
        workCalendarProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await getIt.reset();
      });

      final firstPage = await container.read(workCalendarProvider.future);
      expect(firstPage.items.map((item) => item.id), [
        'appointment-1',
        'appointment-2',
      ]);

      final notifier = container.read(workCalendarProvider.notifier);
      await Future.wait([notifier.loadMore(), notifier.loadMore()]);

      final result = container.read(workCalendarProvider).requireValue;
      expect(result.items.map((item) => item.id), [
        'appointment-1',
        'appointment-2',
        'appointment-3',
      ]);
      expect(result.hasMore, isFalse);
      expect(repository.calls, 2);
      expect(repository.receivedCursors.last, same(cursor));
      expect(repository.receivedLimits, everyElement(workCalendarPageSize));
    },
  );
}

Appointment _appointment(String id) => Appointment(
  id: id,
  salonId: 'salon-1',
  clientId: 'client-1',
  barberId: 'barber-1',
  serviceId: 'service-1',
  serviceName: 'Corte',
  servicePrice: 100,
  serviceCurrency: 'GTQ',
  durationMinutes: 30,
  startAt: DateTime.utc(2026, 8, 5),
  endAt: DateTime.utc(2026, 8, 5, 0, 30),
  timeZone: 'America/Guatemala',
  status: AppointmentStatus.confirmed,
  origin: AppointmentOrigin.app,
);

class _PagedAppointmentRepository implements AppointmentRepository {
  _PagedAppointmentRepository(this.pages);

  final List<WorkCalendarPage> pages;
  final List<WorkCalendarCursor?> receivedCursors = [];
  final List<int> receivedLimits = [];
  int calls = 0;

  @override
  Future<WorkCalendarPage> getBarberAppointmentsPage({
    required String barberId,
    WorkCalendarCursor? cursor,
    int limit = 20,
  }) async {
    receivedCursors.add(cursor);
    receivedLimits.add(limit);
    return pages[calls++];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
