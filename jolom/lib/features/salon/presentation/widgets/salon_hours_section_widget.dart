import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/providers/hour_format_provider.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/core/utils/app_time_format.dart';
import 'package:jolom/features/appointment/presentation/utils/availability_time_utils.dart';

/// Resaltado de la fila del día actual.
enum _TodayHighlight { none, open, closed }

/// Lista read-only Lun–Dom a partir de `availability.weeklyHours`.
class SalonHoursSectionWidget extends ConsumerWidget {
  const SalonHoursSectionWidget({required this.weeklyHours, super.key});

  final Map<String, dynamic> weeklyHours;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final use24h = resolveUse24HourFormat(
      context,
      ref.watch(hourFormatProvider),
    );
    String formatHm(TimeOfDay t) =>
        formatAppTimeOfDay(t, use24HourFormat: use24h);

    final now = DateTime.now();
    final todayKey = availabilityWeekDays[now.weekday - 1];
    final todayOpen = _isOpenNow(todayKey, now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Horario de atención',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final day in availabilityWeekDays) ...[
          _DayHoursRow(
            dayLabel: availabilityWeekDayLabels[day]!,
            hoursLabel: _hoursLabelForDay(day, formatHm),
            highlight: day == todayKey
                ? (todayOpen ? _TodayHighlight.open : _TodayHighlight.closed)
                : _TodayHighlight.none,
          ),
          if (day != availabilityWeekDays.last)
            const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }

  /// `start <= ahora < end` en minutos del día local.
  bool _isOpenNow(String day, DateTime now) {
    final raw = weeklyHours[day];
    if (raw is! Map || raw['start'] == null || raw['end'] == null) {
      return false;
    }
    final dayMap = Map<String, dynamic>.from(raw);
    final start = parseAvailabilityHm(dayMap['start']);
    final end = parseAvailabilityHm(dayMap['end']);
    if (start == null || end == null) return false;
    final nowMinutes = now.hour * 60 + now.minute;
    return nowMinutes >= availabilityTimeToMinutes(start) &&
        nowMinutes < availabilityTimeToMinutes(end);
  }

  String _hoursLabelForDay(String day, String Function(TimeOfDay) formatHm) {
    final raw = weeklyHours[day];
    if (raw is! Map || raw['start'] == null || raw['end'] == null) {
      return 'Cerrado';
    }
    final dayMap = Map<String, dynamic>.from(raw);
    final start = parseAvailabilityHm(dayMap['start']);
    final end = parseAvailabilityHm(dayMap['end']);
    if (start == null || end == null) return 'Cerrado';
    return '${formatHm(start)} – ${formatHm(end)}';
  }
}

class _DayHoursRow extends StatelessWidget {
  const _DayHoursRow({
    required this.dayLabel,
    required this.hoursLabel,
    this.highlight = _TodayHighlight.none,
  });

  final String dayLabel;
  final String hoursLabel;
  final _TodayHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Solo tipografía: abierto = terciario; cerrado ahora = variante atenuada.
    final Color? fg = switch (highlight) {
      _TodayHighlight.open => scheme.tertiary,
      _TodayHighlight.closed => scheme.onSurfaceVariant,
      _TodayHighlight.none => null,
    };

    final isToday = highlight != _TodayHighlight.none;
    final dayStyle = theme.textTheme.bodyMedium?.copyWith(
      color: fg,
      fontWeight: isToday ? FontWeight.w600 : null,
    );
    final hoursStyle = theme.textTheme.bodyMedium?.copyWith(
      color: fg ?? scheme.onSurfaceVariant,
      fontWeight: isToday ? FontWeight.w600 : null,
    );

    return Row(
      children: [
        Text(dayLabel, style: dayStyle),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: _AdaptiveDottedLeader(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ),
        ),
        Text(hoursLabel, style: hoursStyle),
      ],
    );
  }
}

/// Separador que distribuye sus puntos según el espacio horizontal disponible.
class _AdaptiveDottedLeader extends StatelessWidget {
  const _AdaptiveDottedLeader({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: CustomPaint(painter: _DottedLeaderPainter(color: color)),
    );
  }
}

class _DottedLeaderPainter extends CustomPainter {
  const _DottedLeaderPainter({required this.color});

  final Color color;

  static const double _radius = 1.15;
  static const double _preferredGap = 9;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < _radius * 2) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final dotCount = (size.width / _preferredGap).floor().clamp(1, 1000);
    final spacing = size.width / dotCount;
    final y = size.height / 2;

    for (var index = 0; index < dotCount; index++) {
      canvas.drawCircle(Offset((index + 0.5) * spacing, y), _radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLeaderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
