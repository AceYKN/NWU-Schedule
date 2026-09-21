import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nwu_schedule/app/bootstrap.dart';
import 'package:nwu_schedule/core/time/campus_clock.dart';
import 'package:nwu_schedule/core/utils/date_utils.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/data/database/app_database.dart' show AppDatabase;
import 'package:nwu_schedule/data/repositories/drift_schedule_data_repository.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/semester/semester.dart';
import 'package:nwu_schedule/features/calendar/presentation/calendar_page.dart';
import 'package:nwu_schedule/features/home/presentation/home_page.dart';
import 'package:nwu_schedule/features/schedule/presentation/course_detail_page.dart';
import 'package:nwu_schedule/features/schedule/presentation/schedule_page.dart';
import 'package:nwu_schedule/infrastructure/calendar/bundled_calendar_repository.dart';

void main() {
  testWidgets('explains when an imported semester has no bundled calendar',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);
    final semester = Semester(
      id: 'nwu-2027-2028-1',
      academicYear: '2027-2028',
      term: SemesterTerm.first,
      label: '2027-2028 第一学期',
      calendarId: 'nwu-2027-2028-1',
      createdAt: DateTime(2026, 9, 21),
    );
    await repository.saveSemester(semester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          bundledCalendarRepositoryProvider.overrideWithValue(
            _MissingCalendarRepository(),
          ),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('课表已成功读取'), findsOneWidget);
    expect(find.textContaining('当前版本尚未包含'), findsOneWidget);
    expect(find.textContaining('2027-2028 第一学期校历'), findsOneWidget);
    expect(find.textContaining('课程数据已安全保存'), findsOneWidget);
    expect(find.text('查看设置'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('renders the real Home, Week, Month, and Detail pages',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftScheduleDataRepository(database);
    final today = dateOnly(CampusClock.now());
    final week1 = today.subtract(Duration(days: today.weekday - 1 + 7));
    final calendar = CalendarDefinition(
      id: 'widget-pages-calendar',
      school: 'NWU',
      academicYear: '2026-2027',
      term: 1,
      semesterStartDate: week1,
      week1StartDate: week1,
      semesterEndDate: week1.add(const Duration(days: 20 * 7 - 1)),
      totalWeeks: 20,
      revision: 1,
      dateOverrides: const [],
    );
    final semester = Semester(
      id: 'widget-pages-semester',
      academicYear: calendar.academicYear,
      term: SemesterTerm.first,
      label: '2026-2027 第一学期',
      calendarId: calendar.id,
      calendarRevision: calendar.revision,
      createdAt: today,
    );
    final course = Course(
      id: 'widget-pages-course',
      semesterId: semester.id,
      sourceType: CourseSourceType.manual,
      name: '软件测试',
    );
    final rule = MeetingRule(
      id: 'widget-pages-rule',
      courseId: course.id,
      weekday: today.weekday,
      startSection: 3,
      endSection: 4,
      teacher: '教师 A',
      campus: '长安校区',
      room: '3406',
      weekMask: WeekMask.all(calendar.totalWeeks),
    );
    await repository.saveSemester(semester);
    await repository.saveCourse(course, [rule]);
    final weekendCourse = Course(
      id: 'widget-pages-weekend-course',
      semesterId: semester.id,
      sourceType: CourseSourceType.manual,
      name: '周末实验课',
    );
    await repository.saveCourse(
      weekendCourse,
      [
        MeetingRule(
          id: 'widget-pages-weekend-rule',
          courseId: weekendCourse.id,
          weekday: DateTime.saturday,
          startSection: 1,
          endSection: 2,
          weekMask: WeekMask.all(calendar.totalWeeks),
        ),
      ],
    );

    final page = ValueNotifier<Widget>(const HomePage());
    addTearDown(page.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          bundledCalendarRepositoryProvider.overrideWithValue(
            _FixedCalendarRepository(calendar),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<Widget>(
              valueListenable: page,
              builder: (context, child, _) => child,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> pumpPage(Widget next) async {
      page.value = next;
      await tester.pumpAndSettle();
    }

    await pumpPage(const HomePage());
    expect(find.text('软件测试'), findsWidgets);

    await pumpPage(const SchedulePage());
    expect(find.text('周课表'), findsOneWidget);
    expect(find.text('六'), findsOneWidget);
    final courseFinder = find.textContaining('软件测试', skipOffstage: false);
    await tester.ensureVisible(courseFinder);
    await tester.pumpAndSettle();
    expect(find.textContaining('软件测试'), findsOneWidget);

    await pumpPage(const CalendarPage());
    expect(find.byTooltip('选择日期'), findsOneWidget);
    expect(find.text('1 节'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.startsWith('第') &&
            widget.data!.endsWith('周'),
      ),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);

    await pumpPage(const CourseDetailPage(courseId: 'widget-pages-course'));
    expect(find.text('课程详情'), findsOneWidget);
    expect(find.text('软件测试'), findsOneWidget);
    expect(find.text('上课安排'), findsOneWidget);
    expect(find.textContaining('教师 A'), findsOneWidget);
    expect(find.textContaining('第 3-4 节'), findsOneWidget);
    expect(find.textContaining('10:10–12:00'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

class _FixedCalendarRepository extends BundledCalendarRepository {
  _FixedCalendarRepository(this.calendar) : super();

  final CalendarDefinition calendar;

  @override
  Future<CalendarDefinition?> findById(String id) async {
    return id == calendar.id ? calendar : null;
  }
}

class _MissingCalendarRepository extends BundledCalendarRepository {
  @override
  Future<CalendarDefinition?> findById(String id) async => null;
}
