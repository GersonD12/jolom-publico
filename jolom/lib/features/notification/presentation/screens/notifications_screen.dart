import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/navigation/work_appointment_nav.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/providers/hour_format_provider.dart';
import 'package:jolom/core/providers/session_provider.dart';
import 'package:jolom/core/utils/app_time_format.dart';
import 'package:jolom/features/notification/domain/entities/app_notification_entity.dart';
import 'package:jolom/features/notification/domain/entities/appointment_notification_payload.dart';
import 'package:jolom/features/notification/domain/repositories/notification_repository.dart';
import 'package:jolom/features/salon/domain/entities/salon_invitation_entity.dart';
import 'package:jolom/shared/widgets/user_identity.dart';

/// Bandeja in-app de notificaciones.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(notificationsProvider);
    final invitationsAsync = ref.watch(pendingInvitationsProvider);
    final session = ref.watch(sessionProvider).value;
    final use24h = resolveUse24HourFormat(
      context,
      ref.watch(hourFormatProvider),
    );
    final fmt = appDateTimeFormat(
      use24HourFormat: use24h,
      datePattern: 'dd/MM',
    );
    final invitations = invitationsAsync.value ?? const <SalonInvitation>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: itemsAsync.when(
        loading: () => invitationsAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : _NotificationsBody(
                invitations: invitations,
                items: const [],
                fmt: fmt,
                sessionId: session?.id,
              ),
        error: (e, st) => Center(child: Text(userFacingError(e, st))),
        data: (items) => _NotificationsBody(
          invitations: invitations,
          items: items,
          fmt: fmt,
          sessionId: session?.id,
        ),
      ),
    );
  }
}

class _NotificationsBody extends ConsumerWidget {
  const _NotificationsBody({
    required this.invitations,
    required this.items,
    required this.fmt,
    required this.sessionId,
  });

  final List<SalonInvitation> invitations;
  final List<AppNotification> items;
  final DateFormat fmt;
  final String? sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // +1 por la fila fija de Solicitudes; +1 empty de notificaciones si aplica.
    final showEmptyNotifications = items.isEmpty;
    final itemCount = 1 + (showEmptyNotifications ? 1 : items.length);

    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, i) {
        if (i == 0) {
          return _InvitationRequestsTile(invitations: invitations);
        }
        if (showEmptyNotifications) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            child: Text(
              'Bandeja vacía.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        final n = items[i - 1];
        final unread = n.readAt == null;
        return ListTile(
          leading: Icon(
            unread ? Icons.mark_email_unread : Icons.mark_email_read,
          ),
          title: Text(n.title),
          subtitle: Text('${n.body}\n${fmt.format(n.createdAt.toLocal())}'),
          isThreeLine: true,
          onTap: () async {
            if (sessionId != null && unread) {
              await getIt<NotificationRepository>().markAsRead(
                sessionId!,
                n.id,
              );
            }
            if (n.type == AppointmentNotificationPayload.type) {
              final payload = AppointmentNotificationPayload.tryParse(n.data);
              if (payload == null) {
                if (kDebugMode) {
                  debugPrint(
                    'Bandeja: notificación de cita ${n.id} ignorada; '
                    'payload incompleto o inválido.',
                  );
                }
                return;
              }
              if (!context.mounted) return;
              openAppointmentFromNotification(
                ref,
                payload.appointmentId,
                payload.openMode,
              );
            }
          },
        );
      },
    );
  }
}

/// Fila superior estilo Instagram: invitaciones de equipo (siempre visible).
class _InvitationRequestsTile extends StatelessWidget {
  const _InvitationRequestsTile({required this.invitations});

  final List<SalonInvitation> invitations;

  @override
  Widget build(BuildContext context) {
    final count = invitations.length;
    final hasRequests = count > 0;
    final subtitle = hasRequests
        ? (count == 1
              ? '1 invitación pendiente'
              : '$count invitaciones pendientes')
        : 'No tienes invitaciones pendientes';

    return Column(
      children: [
        ListTile(
          leading: hasRequests
              ? UserAvatar(userId: invitations.first.inviterId)
              : CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.person_add_alt_1_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
          title: const Text('Invitaciones'),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/invitations'),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
