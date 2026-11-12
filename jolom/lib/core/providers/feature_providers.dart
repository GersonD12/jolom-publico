import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/providers/session_provider.dart';
import 'package:jolom/features/appointment/domain/entities/appointment_entity.dart';
import 'package:jolom/features/appointment/domain/entities/availability_entity.dart';
import 'package:jolom/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:jolom/features/notification/domain/entities/app_notification_entity.dart';
import 'package:jolom/features/notification/domain/repositories/notification_repository.dart';
import 'package:jolom/features/salon/domain/entities/salon_entity.dart';
import 'package:jolom/features/salon/domain/entities/salon_invitation_entity.dart';
import 'package:jolom/features/salon/domain/entities/salon_membership_entity.dart';
import 'package:jolom/features/salon/domain/repositories/salon_repository.dart';

/// Modo de la app: cliente u operación (trabajo).
enum AppMode { client, work }

class AppModeNotifier extends Notifier<AppMode> {
  @override
  AppMode build() => AppMode.client;

  // ignore: use_setters_to_change_properties
  void setMode(AppMode mode) => state = mode;
}

final appModeProvider = NotifierProvider<AppModeNotifier, AppMode>(
  AppModeNotifier.new,
);

/// Pertenencia activa del usuario autenticado.
final membershipProvider = StreamProvider<SalonMembership?>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) return Stream.value(null);
  return getIt<SalonRepository>().watchMembership(session.id);
});

/// Alerta liviana del horario del usuario actual para el menú de modo trabajo.
///
/// No bloquea la navegación: durante carga/error la UI simplemente no muestra
/// el indicador. `autoDispose` libera el listener al salir del modo trabajo.
final weeklyScheduleNeedsAttentionProvider = StreamProvider.autoDispose<bool>((
  ref,
) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) return Stream.value(false);
  return getIt<AppointmentRepository>()
      .watchAvailabilityWeeklyHours(session.id)
      .map((weeklyHours) => !hasAnyOpenAvailabilityDay(weeklyHours));
});

final publishedSalonsProvider = StreamProvider<List<Salon>>((ref) {
  return getIt<SalonRepository>().watchPublishedSalons();
});

final barberAppointmentsProvider = StreamProvider<List<Appointment>>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) return Stream.value(const []);
  return getIt<AppointmentRepository>().watchBarberAppointments(session.id);
});

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) return Stream.value(const []);
  return getIt<NotificationRepository>().watchNotifications(session.id);
});

/// Invitaciones de equipo pendientes del usuario autenticado.
final pendingInvitationsProvider = FutureProvider<List<SalonInvitation>>((
  ref,
) async {
  final session = ref.watch(sessionProvider).value;
  if (session == null) return const [];
  return getIt<SalonRepository>().listPendingInvitationsForUser(session.id);
});

/// Selección de reserva pendiente de autenticación (APP-03).
class PendingBooking {
  const PendingBooking({
    required this.salonId,
    required this.serviceId,
    required this.barberId,
    required this.startAt,
    this.origin = 'app',
  });

  final String salonId;
  final String serviceId;
  final String barberId;
  final DateTime startAt;
  final String origin;
}

class PendingBookingNotifier extends Notifier<PendingBooking?> {
  @override
  PendingBooking? build() => null;

  // ignore: use_setters_to_change_properties
  void set(PendingBooking? value) => state = value;
}

final pendingBookingProvider =
    NotifierProvider<PendingBookingNotifier, PendingBooking?>(
      PendingBookingNotifier.new,
    );

/// Cita a resaltar en modo trabajo (tap de notificación de solicitud).
class HighlightedAppointmentNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  // ignore: use_setters_to_change_properties
  void highlight(String? appointmentId) => state = appointmentId;

  void clear() => state = null;
}

final highlightedAppointmentIdProvider =
    NotifierProvider<HighlightedAppointmentNotifier, String?>(
      HighlightedAppointmentNotifier.new,
    );

/// Cita recién reservada que se resalta al abrir la agenda del cliente.
class HighlightedClientAppointmentNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void highlight(String appointmentId) => state = appointmentId;

  void clear() => state = null;
}

final highlightedClientAppointmentIdProvider =
    NotifierProvider<HighlightedClientAppointmentNotifier, String?>(
      HighlightedClientAppointmentNotifier.new,
    );

/// Estado reutilizable para formularios con cambios pendientes.
class UnsavedChangesNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markDirty() => state = true;

  void clear() => state = false;

  // ignore: use_setters_to_change_properties
  void setDirty(bool value) => state = value;
}

final availabilityUnsavedChangesProvider =
    NotifierProvider<UnsavedChangesNotifier, bool>(UnsavedChangesNotifier.new);

final editSalonUnsavedChangesProvider =
    NotifierProvider<UnsavedChangesNotifier, bool>(UnsavedChangesNotifier.new);

final completeSalonSetupUnsavedChangesProvider =
    NotifierProvider<UnsavedChangesNotifier, bool>(UnsavedChangesNotifier.new);

final firstServiceUnsavedChangesProvider =
    NotifierProvider<UnsavedChangesNotifier, bool>(UnsavedChangesNotifier.new);

final initialScheduleUnsavedChangesProvider =
    NotifierProvider<UnsavedChangesNotifier, bool>(UnsavedChangesNotifier.new);
