import 'package:flutter/material.dart';
import 'package:jolom/core/theme/theme.dart';

/// Tira horizontal de fechas (hoy → futuro); navegar deslizando.
class BookingSchedulePickerWidget extends StatelessWidget {
  const BookingSchedulePickerWidget({
    required this.selectedDay,
    required this.onDaySelected,
    this.maxDayOffset = 14,
    super.key,
  });

  /// Día seleccionado (sin hora).
  final DateTime selectedDay;

  final ValueChanged<DateTime> onDaySelected;

  /// Último día seleccionable relativo a hoy (0 = hoy, 14 = hoy+14).
  final int maxDayOffset;

  static const _weekdayShort = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];

  static const _monthShort = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime day) {
    if (_isSameDay(day, _today)) return 'Hoy';
    return _weekdayShort[day.weekday - 1];
  }

  String _monthLabel(DateTime day) => _monthShort[day.month - 1];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dayCount = maxDayOffset + 1;

    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: dayCount,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final day = _today.add(Duration(days: i));
          final selected = _isSameDay(day, selectedDay);
          final fg = selected ? scheme.onPrimary : scheme.onSurfaceVariant;

          return Material(
            color: selected ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: AppRadius.pill,
            child: InkWell(
              onTap: () => onDaySelected(day),
              borderRadius: AppRadius.pill,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm,
                  horizontal: AppSpacing.md,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _dayLabel(day),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: textTheme.labelSmall?.copyWith(color: fg),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${day.day}',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _monthLabel(day),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: textTheme.labelSmall?.copyWith(color: fg),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
