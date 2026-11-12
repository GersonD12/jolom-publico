import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jolom/core/providers/hour_format_provider.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';
import 'package:jolom/core/utils/app_time_format.dart';
import 'package:jolom/features/appointment/domain/entities/availability_entity.dart';

/// Pestaña de lista de ausencias / excepciones.
class AvailabilityAbsencesTabWidget extends ConsumerWidget {
  const AvailabilityAbsencesTabWidget({
    required this.exceptions,
    required this.onAdd,
    required this.onDelete,
    super.key,
  });

  final List<AvailabilityException> exceptions;
  final VoidCallback onAdd;
  final ValueChanged<AvailabilityException> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final use24h = resolveUse24HourFormat(
      context,
      ref.watch(hourFormatProvider),
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: appScrollPadding(
        context,
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
        bottom: appBottomActionClearance,
      ),
      children: [
        Text(
          'Marca días o rangos en los que no atiendes: un día completo, varios '
          'días seguidos, o solo unas horas fijas en días concretos. No cambia '
          'tu horario semanal habitual.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Añadir'),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (exceptions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(child: Text('Sin ausencias.')),
          )
        else
          ...exceptions.map(
            (ex) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                ),
                leading: Icon(
                  ex.isTimeOff
                      ? Icons.event_busy_outlined
                      : Icons.schedule_outlined,
                ),
                title: Text(_title(ex)),
                subtitle: Text(_subtitle(ex, use24HourFormat: use24h)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onDelete(ex),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _title(AvailabilityException ex) =>
      ex.isTimeOff ? 'Día completo' : 'Con horario';

  static String _subtitle(
    AvailabilityException ex, {
    required bool use24HourFormat,
  }) {
    final dateFmt = DateFormat.yMMMd();
    final range = ex.isTimeOff
        ? (ex.endAt.difference(ex.startAt).inDays <= 1
              ? dateFmt.format(ex.startAt)
              : '${dateFmt.format(ex.startAt)} – '
                    '${dateFmt.format(ex.endAt.subtract(const Duration(days: 1)))}')
        : '${dateFmt.format(ex.startAt)} · '
              '${formatAppTimeOfDay(TimeOfDay.fromDateTime(ex.startAt), use24HourFormat: use24HourFormat)}–'
              '${formatAppTimeOfDay(TimeOfDay.fromDateTime(ex.endAt), use24HourFormat: use24HourFormat)}';
    final reason = ex.reason?.trim();
    if (reason == null || reason.isEmpty) return range;
    return '$range · $reason';
  }
}
