import 'appointment_entity.dart';
import 'work_calendar_cursor_entity.dart';

/// Página de citas de la agenda de trabajo.
class WorkCalendarPage {
  const WorkCalendarPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  const WorkCalendarPage.empty()
    : items = const [],
      hasMore = false,
      nextCursor = null;

  final List<Appointment> items;
  final bool hasMore;
  final WorkCalendarCursor? nextCursor;
}
