import '../../core/utils/date_utils.dart';
import 'calendar_definition.dart';

class ResolvedCalendarDate {
  const ResolvedCalendarDate({
    required this.actualDate,
    required this.templateDate,
    required this.isTeachingDay,
    required this.teachingWeek,
    required this.teachingWeekday,
    this.label,
    this.override,
  });

  final DateTime actualDate;
  final DateTime? templateDate;
  final bool isTeachingDay;
  final int? teachingWeek;
  final int? teachingWeekday;
  final String? label;
  final CalendarDateOverride? override;
}

class CalendarEngine {
  const CalendarEngine(this.definition);

  final CalendarDefinition definition;

  int? weekOf(DateTime date) {
    final value = dateOnly(date);
    if (value.isBefore(definition.week1StartDate) ||
        value.isAfter(definition.semesterEndDate)) {
      return null;
    }
    final week = value.difference(definition.week1StartDate).inDays ~/ 7 + 1;
    if (week < 1 || week > definition.totalWeeks) {
      return null;
    }
    return week;
  }

  ResolvedCalendarDate resolve(DateTime date) {
    final actualDate = dateOnly(date);
    final week = weekOf(actualDate);
    final override = definition.overrideFor(actualDate);

    if (override?.type == CalendarOverrideType.holiday) {
      return ResolvedCalendarDate(
        actualDate: actualDate,
        templateDate: null,
        isTeachingDay: false,
        teachingWeek: week,
        teachingWeekday: actualDate.weekday,
        label: override!.label,
        override: override,
      );
    }

    // A useScheduleOf source date is resolved only as a template. Its own
    // override is intentionally not recursively applied.
    final templateDate = override?.sourceDate ?? actualDate;
    final templateWeek = weekOf(templateDate);
    return ResolvedCalendarDate(
      actualDate: actualDate,
      templateDate: templateDate,
      isTeachingDay: templateWeek != null,
      teachingWeek: templateWeek,
      teachingWeekday: templateDate.weekday,
      label: override?.label,
      override: override,
    );
  }
}
