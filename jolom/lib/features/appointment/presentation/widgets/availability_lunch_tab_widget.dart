import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/providers/hour_format_provider.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';
import 'package:jolom/core/utils/app_time_format.dart';
import 'package:jolom/shared/widgets/pulsing_save_button_widget.dart';

/// Pestaña de pausa de almuerzo recurrente.
class AvailabilityLunchTabWidget extends ConsumerWidget {
  const AvailabilityLunchTabWidget({
    required this.enabled,
    required this.start,
    required this.end,
    required this.dirty,
    required this.saving,
    required this.onEnabledChanged,
    required this.onPickTime,
    required this.onSave,
    super.key,
  });

  final bool enabled;
  final TimeOfDay start;
  final TimeOfDay end;
  final bool dirty;
  final bool saving;
  final ValueChanged<bool> onEnabledChanged;
  final void Function({required bool isStart}) onPickTime;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final use24h = resolveUse24HourFormat(
      context,
      ref.watch(hourFormatProvider),
    );
    String label(TimeOfDay t) => formatAppTimeOfDay(t, use24HourFormat: use24h);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: appScrollPadding(
        context,
        horizontal: 16,
        vertical: 16,
        bottom: appBottomActionClearance,
      ),
      children: [
        Text(
          'Define una pausa fija (por ejemplo almuerzo) que se aplica a todos '
          'los días abiertos del horario semanal. En ese rango no se podrán '
          'reservar citas.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Hora de almuerzo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Switch(value: enabled, onChanged: onEnabledChanged),
          ],
        ),
        if (enabled) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onPickTime(isStart: true),
                  child: Text('Inicio ${label(start)}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onPickTime(isStart: false),
                  child: Text('Fin ${label(end)}'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        PulsingSaveButtonWidget(
          pulse: dirty,
          label: 'Guardar almuerzo',
          loading: saving,
          onPressed: onSave,
        ),
      ],
    );
  }
}
