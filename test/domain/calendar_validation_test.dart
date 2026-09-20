import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/date_utils.dart';
import 'package:nwu_schedule/domain/calendar/calendar_catalog.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/calendar/calendar_engine.dart';
import 'package:nwu_schedule/infrastructure/calendar/bundled_calendar_repository.dart';

Map<String, dynamic> validCalendar() => {
      'id': 'nwu-2026-2027-1',
      'school': 'NWU',
      'academicYear': '2026-2027',
      'term': 1,
      'semesterStartDate': '2026-08-31',
      'week1StartDate': '2026-08-31',
      'semesterEndDate': '2027-01-15',
      'totalWeeks': 20,
      'revision': 1,
      'dateOverrides': [],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rejects impossible dates and invalid calendar metadata', () {
    expect(() => parseDateOnly('2026-02-30'), throwsFormatException);
    expect(() => CalendarDefinition.fromJson(validCalendar()), returnsNormally);
    for (final invalid in [
      {'academicYear': '2026-2028'},
      {'revision': 0},
      {'week1StartDate': '2026-09-01'},
      {'totalWeeks': 21},
      {
        'dateOverrides': [
          {'date': '2027-01-16', 'type': 'holiday', 'label': '学期外'},
        ],
      },
    ]) {
      expect(
        () => CalendarDefinition.fromJson({...validCalendar(), ...invalid}),
        throwsFormatException,
      );
    }
  });

  test('rejects fractional calendar numeric fields instead of truncating', () {
    for (final invalid in [
      {'term': 1.5},
      {'totalWeeks': 20.5},
      {'revision': 1.5},
      {
        'followingBreak': {
          'kind': 'winter',
          'label': '寒假',
          'startDate': '2027-01-16',
          'endDate': '2027-01-20',
          'reportedDays': 5.5,
        },
      },
    ]) {
      expect(
        () => CalendarDefinition.fromJson({...validCalendar(), ...invalid}),
        throwsFormatException,
      );
    }
  });

  test('catalog rejects duplicate ids, assets and unsafe file names', () {
    final catalog = CalendarCatalog.fromJson({
      'school': 'NWU',
      'calendars': [
        {'id': 'nwu-2026-2027-1', 'asset': '2026-2027-1.json'},
      ],
    });
    expect(catalog.findById('nwu-2026-2027-1')?.asset, '2026-2027-1.json');
    for (final duplicate in [
      {'id': 'nwu-2026-2027-1', 'asset': 'other.json'},
      {'id': 'other', 'asset': '2026-2027-1.json'},
      {'id': 'other', 'asset': '../other.json'},
    ]) {
      expect(
        () => CalendarCatalog.fromJson({
          'school': 'NWU',
          'calendars': [
            {'id': 'nwu-2026-2027-1', 'asset': '2026-2027-1.json'},
            duplicate,
          ],
        }),
        throwsFormatException,
      );
    }
  });

  test('compact holidays and makeup days normalize without recursion', () {
    final definition = CalendarDefinition.fromJson({
      ...validCalendar(),
      'schemaVersion': 1,
      'dateOverrides': [],
      'holidayPeriods': [
        {'name': '国庆节', 'startDate': '2026-10-01', 'endDate': '2026-10-07'},
      ],
      'makeupDays': [
        {
          'date': '2026-10-10',
          'useScheduleOf': '2026-10-06',
          'label': '国庆节调休',
        },
      ],
      'followingBreak': {
        'kind': 'winter',
        'label': '寒假',
        'startDate': '2027-01-16',
        'endDate': '2027-01-20',
        'reportedDays': 5,
      },
    });
    expect(definition.dateOverrides.length, 8);
    expect(definition.followingBreak?.actualDays, 5);
    final engine = CalendarEngine(definition);
    expect(engine.resolve(DateTime(2026, 10, 6)).isTeachingDay, isFalse);
    final makeup = engine.resolve(DateTime(2026, 10, 10));
    expect(makeup.isTeachingDay, isTrue);
    expect(makeup.teachingWeekday, DateTime.tuesday);
    expect(makeup.templateDate, DateTime(2026, 10, 6));
  });

  test('compact calendar rejects overlaps and invalid ranges', () {
    for (final invalid in [
      {
        'holidayPeriods': [
          {'name': '假期', 'startDate': '2026-10-02', 'endDate': '2026-10-01'},
        ],
      },
      {
        'holidayPeriods': [
          {'name': '假期', 'startDate': '2026-10-01', 'endDate': '2026-10-03'},
        ],
        'makeupDays': [
          {'date': '2026-10-02', 'useScheduleOf': '2026-10-05'},
        ],
      },
      {
        'followingBreak': {
          'kind': 'winter',
          'label': '寒假',
          'startDate': '2027-01-14',
          'endDate': '2027-01-20',
        },
      },
    ]) {
      expect(
        () => CalendarDefinition.fromJson({...validCalendar(), ...invalid}),
        throwsFormatException,
      );
    }
  });

  test('all five bundled source calendars load through the runtime catalog',
      () async {
    const repository = BundledCalendarRepository();
    final entries = await repository.listCalendars();
    expect(entries, hasLength(5));
    for (final entry in entries) {
      final definition = await repository.findById(entry.id);
      expect(definition?.id, entry.id);
      expect(definition?.followingBreak, isNotNull);
      expect(definition!.dateOverrides, isNotEmpty);
    }
    final latest = await repository.findById('nwu-2026-2027-1');
    expect(latest?.overrideFor(DateTime(2026, 10, 10))?.sourceDate,
        DateTime(2026, 10, 6));
  });
}
