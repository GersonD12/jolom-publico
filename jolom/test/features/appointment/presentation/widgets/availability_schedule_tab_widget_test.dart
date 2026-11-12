import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/features/appointment/presentation/utils/availability_time_utils.dart';
import 'package:jolom/features/appointment/presentation/widgets/availability_schedule_tab_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('muestra el aviso solo cuando todos los días están cerrados', (
    tester,
  ) async {
    final enabled = {for (final day in availabilityWeekDays) day: false};

    await tester.pumpWidget(_testApp(enabled));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('closed-schedule-notice')),
      findsOneWidget,
    );
    expect(find.text('Tu horario está cerrado'), findsOneWidget);
    expect(find.textContaining('puedan hacer reservaciones'), findsOneWidget);

    enabled['mon'] = true;
    await tester.pumpWidget(_testApp(enabled));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('closed-schedule-notice')), findsNothing);
  });
}

Widget _testApp(Map<String, bool> enabled) {
  final starts = {
    for (final day in availabilityWeekDays)
      day: const TimeOfDay(hour: 9, minute: 0),
  };
  final ends = {
    for (final day in availabilityWeekDays)
      day: const TimeOfDay(hour: 18, minute: 0),
  };
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: AvailabilityScheduleTabWidget(
          days: availabilityWeekDays,
          labels: availabilityWeekDayLabels,
          enabled: enabled,
          dayStart: starts,
          dayEnd: ends,
          dirty: false,
          saving: false,
          onDayEnabledChanged: (_, _) {},
          onPickDayTime: (_, {required isStart}) {},
          onSave: () {},
        ),
      ),
    ),
  );
}
