import 'package:flutter/material.dart';

/// Muestra los primeros 6 caracteres del ID de una cita (prefijo `#`).
class AppointmentIdLabelWidget extends StatelessWidget {
  const AppointmentIdLabelWidget({
    required this.appointmentId,
    super.key,
  });

  final String appointmentId;

  /// Formato corto reutilizable (ej. `#Ab3xY9`).
  static String format(String appointmentId) {
    if (appointmentId.isEmpty) return '#';
    final short = appointmentId.length <= 6
        ? appointmentId
        : appointmentId.substring(0, 6);
    return '#$short';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      format(appointmentId),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace',
          ),
    );
  }
}
