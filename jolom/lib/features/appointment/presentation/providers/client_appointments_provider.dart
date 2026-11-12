import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/providers/session_provider.dart';

import '../../application/use_cases/get_client_appointment_history_page_use_case.dart';
import '../../application/use_cases/watch_upcoming_client_appointments_use_case.dart';
import '../../domain/entities/appointment_entity.dart';
import '../../domain/entities/appointment_history_cursor_entity.dart';

const clientAppointmentHistoryPageSize = 7;
const clientAppointmentCacheMaxAge = Duration(minutes: 5);

/// Últimas citas activas mostradas durante la sesión del usuario.
class ClientUpcomingAppointmentsCacheNotifier
    extends Notifier<List<Appointment>?> {
  @override
  List<Appointment>? build() {
    ref.watch(sessionProvider);
    return null;
  }

  void update(List<Appointment> items) => state = items;
}

final clientUpcomingAppointmentsCacheProvider =
    NotifierProvider<
      ClientUpcomingAppointmentsCacheNotifier,
      List<Appointment>?
    >(ClientUpcomingAppointmentsCacheNotifier.new);

/// Citas activas del cliente; el listener se cierra al salir de la pantalla.
final clientUpcomingAppointmentsProvider =
    StreamProvider.autoDispose<List<Appointment>>((ref) {
      final session = ref.watch(sessionProvider).value;
      if (session == null) return Stream.value(const []);

      return getIt<WatchUpcomingClientAppointmentsUseCase>()(session.id).map((
        items,
      ) {
        final previous = ref.read(clientUpcomingAppointmentsCacheProvider);
        ref
            .read(clientUpcomingAppointmentsCacheProvider.notifier)
            .update(items);

        if (previous != null) {
          final currentIds = items.map((item) => item.id).toSet();
          final removedActiveAppointment = previous.any(
            (item) => !currentIds.contains(item.id),
          );
          final history = ref.read(clientAppointmentHistoryProvider);
          if (removedActiveAppointment && history.hasValue) {
            // ignore: discarded_futures
            ref
                .read(clientAppointmentHistoryProvider.notifier)
                .refreshFirstPage(force: true);
          }
        }
        return items;
      });
    });

/// Estado acumulado de las páginas ya solicitadas del historial.
class ClientAppointmentHistoryState {
  const ClientAppointmentHistoryState({
    required this.items,
    required this.hasMore,
    this.nextCursor,
    this.isLoadingMore = false,
    this.paginationError,
    this.paginationStackTrace,
    this.lastSyncedAt,
  });

  const ClientAppointmentHistoryState.empty()
    : items = const [],
      hasMore = false,
      nextCursor = null,
      isLoadingMore = false,
      paginationError = null,
      paginationStackTrace = null,
      lastSyncedAt = null;

  final List<Appointment> items;
  final bool hasMore;
  final AppointmentHistoryCursor? nextCursor;
  final bool isLoadingMore;
  final Object? paginationError;
  final StackTrace? paginationStackTrace;
  final DateTime? lastSyncedAt;

  ClientAppointmentHistoryState loadingMore() {
    return ClientAppointmentHistoryState(
      items: items,
      hasMore: hasMore,
      nextCursor: nextCursor,
      isLoadingMore: true,
      lastSyncedAt: lastSyncedAt,
    );
  }

  ClientAppointmentHistoryState withPaginationError(
    Object error,
    StackTrace stackTrace,
  ) {
    return ClientAppointmentHistoryState(
      items: items,
      hasMore: hasMore,
      nextCursor: nextCursor,
      paginationError: error,
      paginationStackTrace: stackTrace,
      lastSyncedAt: lastSyncedAt,
    );
  }
}

class ClientAppointmentHistoryNotifier
    extends AsyncNotifier<ClientAppointmentHistoryState> {
  bool _requestInProgress = false;

  @override
  Future<ClientAppointmentHistoryState> build() async {
    _requestInProgress = false;
    final session = ref.watch(sessionProvider).value;
    if (session == null) return const ClientAppointmentHistoryState.empty();

    final page = await getIt<GetClientAppointmentHistoryPageUseCase>()(
      clientId: session.id,
      limit: clientAppointmentHistoryPageSize,
    );
    return ClientAppointmentHistoryState(
      items: page.items,
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
      lastSyncedAt: DateTime.now(),
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
      final page = await getIt<GetClientAppointmentHistoryPageUseCase>()(
        clientId: session.id,
        cursor: current.nextCursor,
        limit: clientAppointmentHistoryPageSize,
      );
      state = AsyncData(
        ClientAppointmentHistoryState(
          items: [...current.items, ...page.items],
          hasMore: page.hasMore,
          nextCursor: page.nextCursor,
          lastSyncedAt: current.lastSyncedAt,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncData(current.withPaginationError(error, stackTrace));
    } finally {
      _requestInProgress = false;
    }
  }

  /// Revalida la primera página sin reemplazar los datos por un loader.
  Future<void> refreshFirstPage({bool force = false}) async {
    final current = state.value;
    final session = ref.read(sessionProvider).value;
    if (_requestInProgress || current == null || session == null) return;

    final lastSyncedAt = current.lastSyncedAt;
    if (!force &&
        lastSyncedAt != null &&
        DateTime.now().difference(lastSyncedAt) <
            clientAppointmentCacheMaxAge) {
      return;
    }

    _requestInProgress = true;
    try {
      final page = await getIt<GetClientAppointmentHistoryPageUseCase>()(
        clientId: session.id,
        limit: clientAppointmentHistoryPageSize,
      );
      state = AsyncData(
        ClientAppointmentHistoryState(
          items: page.items,
          hasMore: page.hasMore,
          nextCursor: page.nextCursor,
          lastSyncedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      // La revalidación es silenciosa: se conservan los últimos datos válidos.
    } finally {
      _requestInProgress = false;
    }
  }
}

final clientAppointmentHistoryProvider =
    AsyncNotifierProvider<
      ClientAppointmentHistoryNotifier,
      ClientAppointmentHistoryState
    >(ClientAppointmentHistoryNotifier.new);
