import '../../core/time/campus_clock.dart';
import '../../core/utils/date_utils.dart';
import '../calendar/calendar_definition.dart';
import 'semester.dart';

typedef CalendarById = Future<CalendarDefinition?> Function(String id);

/// A manual choice remains active until a later semester actually starts.
Future<Semester> selectSemester({
  required List<Semester> semesters,
  required String? preferredId,
  required DateTime? preferredSelectedAt,
  required CalendarById calendarById,
  required DateTime today,
}) async {
  if (semesters.isEmpty) throw ArgumentError('No semesters to select');
  final campusToday = dateOnly(today);
  Semester? preferred;
  for (final semester in semesters) {
    if (semester.id == preferredId) preferred = semester;
  }
  Semester? current;
  CalendarDefinition? currentCalendar;
  Semester? latestStarted;
  CalendarDefinition? latestStartedCalendar;
  Semester? earliestFuture;
  CalendarDefinition? earliestFutureCalendar;
  for (final semester in semesters) {
    final id = semester.calendarId;
    final calendar = id == null ? null : await calendarById(id);
    if (calendar == null) continue;
    if (campusToday.isBefore(calendar.semesterStartDate)) {
      if (earliestFutureCalendar == null ||
          calendar.semesterStartDate
              .isBefore(earliestFutureCalendar.semesterStartDate)) {
        earliestFuture = semester;
        earliestFutureCalendar = calendar;
      }
      continue;
    }
    if (latestStartedCalendar == null ||
        calendar.semesterStartDate
            .isAfter(latestStartedCalendar.semesterStartDate)) {
      latestStarted = semester;
      latestStartedCalendar = calendar;
    }
    if (campusToday.isAfter(calendar.semesterEndDate)) continue;
    if (currentCalendar == null ||
        calendar.semesterStartDate.isAfter(currentCalendar.semesterStartDate)) {
      current = semester;
      currentCalendar = calendar;
    }
  }
  if (preferred != null) {
    final selectedDate = preferredSelectedAt == null
        ? null
        : dateOnly(CampusClock.toCampusWallTime(preferredSelectedAt));
    if (current == null ||
        selectedDate == null ||
        !currentCalendar!.semesterStartDate.isAfter(selectedDate)) {
      return preferred;
    }
  }
  if (current != null) return current;
  if (latestStarted != null) return latestStarted;
  if (earliestFuture != null) return earliestFuture;
  final newest = List<Semester>.of(semesters)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return newest.first;
}
