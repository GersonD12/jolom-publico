import 'package:flutter/material.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/features/appointment/domain/entities/appointment_entity.dart';
import 'package:jolom/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:jolom/shared/widgets/app_modal_bottom_sheet.dart';

/// Acciones de negocio en UI según estado.
/// En `pending` solo confirmar/rechazar (alineado a work home); `cancelledByBusiness`
/// se ofrece desde `confirmed`. El backend aún permite más transiciones.
List<AppointmentStatus> businessStatusActionsFor(Appointment appointment) {
  final now = DateTime.now();
  if (appointment.status == AppointmentStatus.pending) {
    return [AppointmentStatus.confirmed, AppointmentStatus.rejected];
  }
  if (appointment.status == AppointmentStatus.confirmed) {
    final actions = <AppointmentStatus>[AppointmentStatus.cancelledByBusiness];
    // completed / noShow solo tras la hora programada (backend).
    if (appointment.startAt.isBefore(now)) {
      actions.addAll([AppointmentStatus.completed, AppointmentStatus.noShow]);
    }
    return actions;
  }
  return const [];
}

/// Pide confirmación antes de aplicar un estado sensible a una cita.
///
/// Devuelve `true` directamente para los estados que no requieren confirmación.
Future<bool> confirmAppointmentStatusAction(
  BuildContext context,
  AppointmentStatus status,
) async {
  final copy = switch (status) {
    AppointmentStatus.confirmed => (
      title: 'Aprobar solicitud',
      message:
          '¿Estás seguro de que quieres aprobar esta solicitud? Se notificará al cliente.',
      actionLabel: 'Sí, aprobar',
    ),
    AppointmentStatus.rejected => (
      title: 'Rechazar solicitud',
      message:
          '¿Estás seguro de que quieres rechazar esta solicitud? Se notificará al cliente.',
      actionLabel: 'Sí, rechazar',
    ),
    AppointmentStatus.cancelledByClient => (
      title: 'Cancelar cita',
      message:
          '¿Estás seguro de que quieres cancelar esta cita? El negocio será notificado.',
      actionLabel: 'Sí, cancelar',
    ),
    AppointmentStatus.cancelledByBusiness => (
      title: 'Cancelar cita',
      message:
          '¿Estás seguro de que quieres cancelar esta cita? Se notificará al cliente.',
      actionLabel: 'Sí, cancelar',
    ),
    AppointmentStatus.completed => (
      title: 'Finalizar cita',
      message: '¿Estás seguro de que quieres marcar esta cita como finalizada?',
      actionLabel: 'Sí, finalizar',
    ),
    AppointmentStatus.noShow => (
      title: 'Marcar inasistencia',
      message:
          '¿Estás seguro de que quieres indicar que el cliente no asistió?',
      actionLabel: 'Sí, no asistió',
    ),
    _ => null,
  };
  if (copy == null) return true;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(copy.title),
      content: Text(copy.message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(copy.actionLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Bottom sheet de cambio de estado; aplica la transición si el usuario elige.
Future<void> showAppointmentStatusActions(
  BuildContext context,
  Appointment appointment,
) async {
  final actions = businessStatusActionsFor(appointment);
  if (actions.isEmpty) return;

  final selected = await showAppModalBottomSheet<AppointmentStatus>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: actions
            .map(
              (s) => ListTile(
                title: Text(s.labelEs),
                onTap: () => Navigator.pop(ctx, s),
              ),
            )
            .toList(),
      ),
    ),
  );
  if (selected == null || !context.mounted) return;

  final confirmed = await confirmAppointmentStatusAction(context, selected);
  if (!confirmed || !context.mounted) return;

  try {
    await getIt<AppointmentRepository>().changeAppointmentStatus(
      appointmentId: appointment.id,
      status: selected,
      idempotencyKey: 'changeStatus_${appointment.id}_${selected.name}',
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
  }
}
