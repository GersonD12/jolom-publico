import 'package:flutter/material.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';
import 'package:jolom/shared/widgets/pulsing_save_button_widget.dart';

import 'availability_days_editor_widget.dart';

/// Pestaña de días abiertos y horario por día.
class AvailabilityScheduleTabWidget extends StatelessWidget {
  const AvailabilityScheduleTabWidget({
    required this.days,
    required this.labels,
    required this.enabled,
    required this.dayStart,
    required this.dayEnd,
    required this.dirty,
    required this.saving,
    required this.onDayEnabledChanged,
    required this.onPickDayTime,
    required this.onSave,
    super.key,
  });

  final List<String> days;
  final Map<String, String> labels;
  final Map<String, bool> enabled;
  final Map<String, TimeOfDay> dayStart;
  final Map<String, TimeOfDay> dayEnd;
  final bool dirty;
  final bool saving;
  final void Function(String day, bool enabled) onDayEnabledChanged;
  final void Function(String day, {required bool isStart}) onPickDayTime;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasOpenDay = days.any((day) => enabled[day] == true);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: appScrollPadding(
        context,
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
        bottom: appBottomActionClearance,
      ),
      children: [
        if (!hasOpenDay) ...[
          Container(
            key: const ValueKey('closed-schedule-notice'),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: AppRadius.cardCompact,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.schedule_outlined,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tu horario está cerrado',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Activa al menos un día y guarda el horario para que '
                        'las personas puedan hacer reservaciones.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AvailabilityDaysEditorWidget(
          days: days,
          labels: labels,
          enabled: enabled,
          dayStart: dayStart,
          dayEnd: dayEnd,
          onDayEnabledChanged: onDayEnabledChanged,
          onPickDayTime: onPickDayTime,
        ),
        const SizedBox(height: AppSpacing.sm),
        PulsingSaveButtonWidget(
          pulse: dirty,
          label: 'Guardar horario',
          loading: saving,
          onPressed: onSave,
        ),
      ],
    );
  }
}
