import 'appointment_entity.dart';
import 'appointment_history_cursor_entity.dart';

/// Página de citas históricas obtenida desde el repositorio.
class AppointmentHistoryPage {
  const AppointmentHistoryPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  const AppointmentHistoryPage.empty()
    : items = const [],
      hasMore = false,
      nextCursor = null;

  final List<Appointment> items;
  final bool hasMore;
  final AppointmentHistoryCursor? nextCursor;
}
