import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/semester/semester.dart';
import 'package:nwu_schedule/domain/semester/semester_selector.dart';

void main() {
  final first = Semester(
    id: 'first',
    academicYear: '2026-2027',
    term: SemesterTerm.first,
    label: '第一学期',
    calendarId: 'first-calendar',
    createdAt: DateTime(2026, 8, 20),
  );
  final second = Semester(
    id: 'second',
    academicYear: '2026-2027',
    term: SemesterTerm.second,
    label: '第二学期',
    calendarId: 'second-calendar',
    createdAt: DateTime(2026, 12, 1),
  );
  final calendars = <String, CalendarDefinition>{
    'first-calendar': CalendarDefinition.fromJson({
      'id': 'first-calendar',
      'school': 'NWU',
      'academicYear': '2026-2027',
      'term': 1,
      'semesterStartDate': '2026-08-31',
      'week1StartDate': '2026-08-31',
      'semesterEndDate': '2027-01-15',
      'totalWeeks': 20,
      'revision': 1,
      'dateOverrides': [],
    }),
    'second-calendar': CalendarDefinition.fromJson({
      'id': 'second-calendar',
      'school': 'NWU',
      'academicYear': '2026-2027',
      'term': 2,
      'semesterStartDate': '2027-03-01',
      'week1StartDate': '2027-03-01',
      'semesterEndDate': '2027-07-16',
      'totalWeeks': 20,
      'revision': 1,
      'dateOverrides': [],
    }),
  };
  Future<CalendarDefinition?> byId(String id) async => calendars[id];

  test('advance only when the newly imported semester actually starts',
      () async {
    for (final date in [DateTime(2026, 12, 10), DateTime(2027, 2, 1)]) {
      final selected = await selectSemester(
        semesters: [first, second],
        preferredId: first.id,
        preferredSelectedAt: DateTime.utc(2026, 12, 1),
        calendarById: byId,
        today: date,
      );
      expect(selected.id, first.id);
    }
    final selected = await selectSemester(
      semesters: [first, second],
      preferredId: first.id,
      preferredSelectedAt: DateTime.utc(2026, 12, 1),
      calendarById: byId,
      today: DateTime(2027, 3, 1),
    );
    expect(selected.id, second.id);
  });

  test('manual historical selection made this term remains visible', () async {
    final selected = await selectSemester(
      semesters: [first, second],
      preferredId: first.id,
      preferredSelectedAt: DateTime.utc(2027, 3, 5),
      calendarById: byId,
      today: DateTime(2027, 3, 5),
    );
    expect(selected.id, first.id);
  });

  test('without manual selection, break keeps previous semester', () async {
    final selected = await selectSemester(
      semesters: [first, second],
      preferredId: null,
      preferredSelectedAt: null,
      calendarById: byId,
      today: DateTime(2027, 2, 1),
    );
    expect(selected.id, first.id);
  });
}
