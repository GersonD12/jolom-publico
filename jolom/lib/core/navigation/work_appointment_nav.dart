import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/app/routes/routes.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/features/notification/domain/entities/appointment_notification_payload.dart';

/// Abre una cita usando exclusivamente el destino declarado en el payload.
void openAppointmentFromNotification(
  WidgetRef ref,
  String appointmentId,
  AppointmentNotificationOpenMode openMode,
) {
  switch (openMode) {
    case AppointmentNotificationOpenMode.client:
      ref.read(appModeProvider.notifier).setMode(AppMode.client);
      ref
          .read(highlightedClientAppointmentIdProvider.notifier)
          .highlight(appointmentId);
      ref.read(goRouterProvider).go('/appointments');
    case AppointmentNotificationOpenMode.work:
      ref.read(appModeProvider.notifier).setMode(AppMode.work);
      ref
          .read(highlightedAppointmentIdProvider.notifier)
          .highlight(appointmentId);
      ref.read(goRouterProvider).go('/work');
  }
}
