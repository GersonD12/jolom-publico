import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/providers/hour_format_provider.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/core/utils/app_time_format.dart';

/// Editor reutilizable de días abiertos y sus horas de inicio y fin.
class AvailabilityDaysEditorWidget extends ConsumerWidget {
  const AvailabilityDaysEditorWidget({
    required this.days,
    required this.labels,
    required this.enabled,
    required this.dayStart,
    required this.dayEnd,
    required this.onDayEnabledChanged,
    required this.onPickDayTime,
    super.key,
  });

  final List<String> days;
  final Map<String, String> labels;
  final Map<String, bool> enabled;
  final Map<String, TimeOfDay> dayStart;
  final Map<String, TimeOfDay> dayEnd;
  final void Function(String day, bool enabled) onDayEnabledChanged;
  final void Function(String day, {required bool isStart}) onPickDayTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final use24h = resolveUse24HourFormat(
      context,
      ref.watch(hourFormatProvider),
    );
    String label(TimeOfDay time) =>
        formatAppTimeOfDay(time, use24HourFormat: use24h);

    return Column(
      children: days.map((day) {
        final open = enabled[day] == true;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(labels[day]!),
                subtitle: Text(
                  open
                      ? '${label(dayStart[day]!)} – ${label(dayEnd[day]!)}'
                      : 'Cerrado',
                ),
                value: open,
                onChanged: (value) => onDayEnabledChanged(day, value),
              ),
              if (open)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onPickDayTime(day, isStart: true),
                        child: Text('Inicio ${label(dayStart[day]!)}'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onPickDayTime(day, isStart: false),
                        child: Text('Fin ${label(dayEnd[day]!)}'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
