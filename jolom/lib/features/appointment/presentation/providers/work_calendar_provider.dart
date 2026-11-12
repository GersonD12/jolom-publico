import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/providers/session_provider.dart';

import '../../application/use_cases/get_barber_appointments_page_use_case.dart';
import '../../domain/entities/appointment_entity.dart';
import '../../domain/entities/work_calendar_cursor_entity.dart';

const workCalendarPageSize = 20;

/// Estado acumulado de las páginas cargadas en la agenda de trabajo.
class WorkCalendarState {
  const WorkCalendarState({
    required this.items,
    required this.hasMore,
    this.nextCursor,
    this.isLoadingMore = false,
    this.paginationError,
    this.paginationStackTrace,
  });

  const WorkCalendarState.empty()
    : items = const [],
      hasMore = false,
      nextCursor = null,
      isLoadingMore = false,
      paginationError = null,
      paginationStackTrace = null;

  final List<Appointment> items;
  final bool hasMore;
  final WorkCalendarCursor? nextCursor;
  final bool isLoadingMore;
  final Object? paginationError;
  final StackTrace? paginationStackTrace;

  WorkCalendarState loadingMore() => WorkCalendarState(
    items: items,
    hasMore: hasMore,
    nextCursor: nextCursor,
    isLoadingMore: true,
  );

  WorkCalendarState withPaginationError(Object error, StackTrace stackTrace) =>
      WorkCalendarState(
        items: items,
        hasMore: hasMore,
        nextCursor: nextCursor,
        paginationError: error,
        paginationStackTrace: stackTrace,
      );
}

class WorkCalendarNotifier extends AsyncNotifier<WorkCalendarState> {
  bool _requestInProgress = false;

  @override
  Future<WorkCalendarState> build() async {
    _requestInProgress = false;
    final session = ref.watch(sessionProvider).value;
    if (session == null) return const WorkCalendarState.empty();
    return _getFirstPage(session.id);
  }

  Future<WorkCalendarState> _getFirstPage(String barberId) async {
    final page = await getIt<GetBarberAppointmentsPageUseCase>()(
      barberId: barberId,
      limit: workCalendarPageSize,
    );
    return WorkCalendarState(
      items: page.items,
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    final session = ref.read(sessionProvider).value;
    if (_requestInProgress ||
        current == null ||
        session == null ||
        !current.hasMore ||
        current.nextCursor == null) {
      return;
    }

    _requestInProgress = true;
    state = AsyncData(current.loadingMore());
    try {
      final page = await getIt<GetBarberAppointmentsPageUseCase>()(
        barberId: session.id,
        cursor: current.nextCursor,
        limit: workCalendarPageSize,
      );
      final knownIds = current.items.map((item) => item.id).toSet();
      state = AsyncData(
        WorkCalendarState(
          items: [
            ...current.items,
            ...page.items.where((item) => knownIds.add(item.id)),
          ],
          hasMore: page.hasMore,
          nextCursor: page.nextCursor,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncData(current.withPaginationError(error, stackTrace));
    } finally {
      _requestInProgress = false;
    }
  }
}

final workCalendarProvider =
    AsyncNotifierProvider.autoDispose<WorkCalendarNotifier, WorkCalendarState>(
      WorkCalendarNotifier.new,
    );
