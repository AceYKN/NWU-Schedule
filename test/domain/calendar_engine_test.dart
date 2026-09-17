import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/calendar/calendar_engine.dart';

CalendarDefinition makeCalendar({
  List<CalendarDateOverride> overrides = const [],
}) {
  return CalendarDefinition(
    id: 'nwu-test-2026-1',
    school: 'NWU',
    academicYear: '2026-2027',
    term: 1,
    semesterStartDate: DateTime(2026, 9, 1),
    week1StartDate: DateTime(2026, 9, 7),
    semesterEndDate: DateTime(2027, 1, 31),
    totalWeeks: 20,
    revision: 1,
    dateOverrides: overrides,
  );
}

void main() {
  test('resolves an ordinary date to week and weekday', () {
    final result = CalendarEngine(makeCalendar()).resolve(DateTime(2026, 9, 9));

    expect(result.isTeachingDay, isTrue);
    expect(result.teachingWeek, 1);
    expect(result.teachingWeekday, DateTime.wednesday);
    expect(result.templateDate, DateTime(2026, 9, 9));
  });

  test('holiday removes the schedule template but keeps teaching week', () {
    final result = CalendarEngine(
      makeCalendar(
        overrides: [
          CalendarDateOverride(
            date: DateTime(2026, 10, 1),
            type: CalendarOverrideType.holiday,
            label: '国庆节',
          ),
        ],
      ),
    ).resolve(DateTime(2026, 10, 1));

    expect(result.isTeachingDay, isFalse);
    expect(result.teachingWeek, 4);
    expect(result.label, '国庆节');
    expect(result.templateDate, isNull);
  });

  test('useScheduleOf uses source week and weekday without recursion', () {
    final result = CalendarEngine(
      makeCalendar(
        overrides: [
          CalendarDateOverride(
            date: DateTime(2026, 9, 12),
            type: CalendarOverrideType.useScheduleOf,
            sourceDate: DateTime(2026, 9, 9),
            label: '调课',
          ),
        ],
      ),
    ).resolve(DateTime(2026, 9, 12));

    expect(result.isTeachingDay, isTrue);
    expect(result.teachingWeek, 1);
    expect(result.teachingWeekday, DateTime.wednesday);
    expect(result.templateDate, DateTime(2026, 9, 9));
  });
}
