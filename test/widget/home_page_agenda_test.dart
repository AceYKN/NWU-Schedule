import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/app/bootstrap.dart';
import 'package:nwu_schedule/core/time/campus_clock.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/calendar/calendar_engine.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/course_exception.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/schedule/schedule_engine.dart';
import 'package:nwu_schedule/domain/semester/semester.dart';
import 'package:nwu_schedule/features/home/presentation/home_page.dart';
import 'package:nwu_schedule/features/shared/presentation/course_card.dart';

void main() {
  testWidgets('switches at campus 22:00 and resets to today at midnight',
      (tester) async {
    final ready = _ready();
    for (final time in [
      DateTime(2026, 9, 7, 21, 59),
      DateTime(2026, 9, 7, 22),
      DateTime(2026, 9, 7, 23, 59),
      DateTime(2026, 9, 8),
    ]) {
      await _pumpHome(tester, ready, time);
      final tomorrow = time.hour >= 22;
      expect(find.text(tomorrow ? '明天' : '今天'), findsOneWidget);
      expect(find.text('明日安排'), tomorrow ? findsOneWidget : findsNothing);
      expect(find.textContaining('明天第一节'),
          tomorrow ? findsOneWidget : findsNothing);
      final card = tester.widget<CourseCard>(find.byType(CourseCard));
      expect(card.instance.courseName, time.hour == 21 ? '今日课程' : '明日课程1');
      expect(card.instance.date,
          time.hour == 21 ? DateTime(2026, 9, 7) : DateTime(2026, 9, 8));
      expect(card.status,
          time.hour == 21 ? '已结束' : (time.hour == 0 ? '下一节' : null));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows tomorrow empty instead of skipping to the next class',
      (tester) async {
    final ready = _ready(overrides: [
      CalendarDateOverride(
        date: DateTime(2026, 9, 8),
        type: CalendarOverrideType.holiday,
        label: '休假',
      ),
    ]);
    await _pumpHome(tester, ready, DateTime(2026, 9, 7, 22));

    expect(find.text('明天'), findsOneWidget);
    expect(find.text('0 节'), findsOneWidget);
    expect(find.text('明天没有排入课程的记录。'), findsOneWidget);
    expect(find.byType(CourseCard), findsNothing);
    expect(find.text('明天暂无课程'), findsOneWidget);
    expect(find.textContaining('7天后 · 星期一 08:00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tomorrow agenda uses the calendar makeup schedule',
      (tester) async {
    final ready = _ready(overrides: [
      CalendarDateOverride(
        date: DateTime(2026, 9, 12),
        type: CalendarOverrideType.useScheduleOf,
        sourceDate: DateTime(2026, 9, 7),
        label: '补课',
      ),
    ]);
    await _pumpHome(tester, ready, DateTime(2026, 9, 11, 22));

    expect(find.text('明天'), findsOneWidget);
    final card = tester.widget<CourseCard>(find.byType(CourseCard));
    expect(card.instance.courseName, '今日课程');
    expect(card.instance.date, DateTime(2026, 9, 12));
    expect(card.status, isNull);
    expect(find.text('明日安排'), findsOneWidget);
    expect(find.textContaining('星期六 · 补课日'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('full agenda shows all tomorrow courses with tomorrow title',
      (tester) async {
    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await _pumpHome(tester, _ready(tomorrowCount: 6), DateTime(2026, 9, 7, 22));

    expect(find.text('6 节'), findsOneWidget);
    expect(find.byType(CourseCard), findsNWidgets(5));
    final button = find.text('查看明日全部课程（6）');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('明日全部课程'), findsOneWidget);
    final sheetCards = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(CourseCard),
    );
    expect(sheetCards, findsNWidgets(6));
    for (final card in tester.widgetList<CourseCard>(sheetCards)) {
      expect(card.instance.date, DateTime(2026, 9, 8));
      expect(card.status, isNull);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('holiday ADD appears as tomorrow first class in the hero',
      (tester) async {
    final ready = _ready(
      overrides: [
        CalendarDateOverride(
          date: DateTime(2026, 9, 8),
          type: CalendarOverrideType.holiday,
          label: '休假',
        ),
      ],
      exceptions: [
        CourseException(
          id: 'holiday-add',
          semesterId: 'agenda-semester',
          type: CourseExceptionType.add,
          targetDate: DateTime(2026, 9, 8),
          targetStartSection: 3,
          targetEndSection: 4,
          addedCourseName: '假期实验',
        ),
      ],
    );
    await _pumpHome(tester, ready, DateTime(2026, 9, 7, 22));
    expect(find.text('明日安排'), findsOneWidget);
    expect(find.textContaining('明天第一节\n校历：休假'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-status-card')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('假期实验'),
      ),
      findsOneWidget,
    );
    expect(find.text('撤销临时变更'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final time in [
    DateTime(2026, 9, 7, 7),
    DateTime(2026, 9, 7, 8),
    DateTime(2026, 9, 7, 22),
  ]) {
    testWidgets('hero opens the displayed course details at ${time.hour}:00',
        (tester) async {
      await _pumpHome(tester, _ready(), time);
      await tester.tap(find.byKey(const ValueKey('home-status-card')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(time.hour == 22 ? '明日课程1' : '今日课程'),
        ),
        findsOneWidget,
      );
      expect(find.text('第 1-2 节'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('live seconds countdown switches to in class at the start',
      (tester) async {
    var now = DateTime(2026, 9, 7, 7, 59, 58);
    await _pumpHome(tester, _ready(), now, clock: () => now);
    expect(find.textContaining('还有 2 秒'), findsOneWidget);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('还有 1 秒'), findsOneWidget);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('正在上课'), findsOneWidget);
    expect(find.textContaining('距离下课 1 小时 50 分钟 0 秒'), findsOneWidget);
    expect(tester.widget<CourseCard>(find.byType(CourseCard)).status, '进行中');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('live countdown ticks inside a minute and finishes at the end',
      (tester) async {
    var now = DateTime(2026, 9, 7, 9, 49, 58);
    await _pumpHome(tester, _ready(), now, clock: () => now);
    expect(find.textContaining('距离下课 2 秒'), findsOneWidget);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('距离下课 1 秒'), findsOneWidget);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('今日完成'), findsOneWidget);
    expect(find.textContaining('距离下课'), findsNothing);
    expect(tester.widget<CourseCard>(find.byType(CourseCard)).status, '已结束');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('fractional seconds round up and minutes retain seconds',
      (tester) async {
    for (final item in [
      (time: DateTime(2026, 9, 7, 7, 58, 59), text: '还有 1 分钟 1 秒'),
      (time: DateTime(2026, 9, 7, 7, 59), text: '还有 1 分钟 0 秒'),
      (time: DateTime(2026, 9, 7, 7, 59, 59, 999), text: '还有 1 秒'),
    ]) {
      await _pumpHome(tester, _ready(), item.time);
      expect(find.textContaining(item.text), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('live clock switches to tomorrow at 22 and today at midnight',
      (tester) async {
    var now = DateTime(2026, 9, 7, 21, 59, 59);
    await _pumpHome(tester, _ready(), now, clock: () => now);
    expect(find.text('今日完成'), findsOneWidget);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('明日安排'), findsOneWidget);
    expect(find.text('明天'), findsOneWidget);
    now = DateTime(2026, 9, 8);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('下一节'), findsNWidgets(2));
    expect(find.text('今天'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('resume refreshes from the clock after background suspension',
      (tester) async {
    var now = DateTime(2026, 9, 7, 7, 59, 59);
    await _pumpHome(tester, _ready(), now, clock: () => now);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 9, 7, 8);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('正在上课'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('正在上课'), findsOneWidget);
    now = DateTime(2026, 9, 7, 8, 0, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('距离下课 1 小时 49 分钟 59 秒'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _pumpHome(
  WidgetTester tester,
  ScheduleReady ready,
  DateTime campusTime, {
  DateTime Function()? clock,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        scheduleLoadProvider.overrideWith((ref) => Stream.value(ready)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: HomePage(
            now: clock == null
                ? CampusClock.campusWallTimeToUtc(campusTime)
                : null,
            clock: clock == null
                ? null
                : () => CampusClock.campusWallTimeToUtc(clock()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ScheduleReady _ready({
  int tomorrowCount = 1,
  List<CalendarDateOverride> overrides = const [],
  List<CourseException> exceptions = const [],
}) {
  final calendar = CalendarDefinition(
    id: 'agenda-calendar',
    school: 'NWU',
    academicYear: '2026-2027',
    term: 1,
    semesterStartDate: DateTime(2026, 9, 7),
    week1StartDate: DateTime(2026, 9, 7),
    semesterEndDate: DateTime(2026, 10, 31),
    totalWeeks: 8,
    revision: 1,
    dateOverrides: overrides,
  );
  final courses = [
    Course(
      id: 'today',
      semesterId: 'agenda-semester',
      sourceType: CourseSourceType.manual,
      name: '今日课程',
    ),
    for (var index = 1; index <= tomorrowCount; index++)
      Course(
        id: 'tomorrow-$index',
        semesterId: 'agenda-semester',
        sourceType: CourseSourceType.manual,
        name: '明日课程$index',
      ),
  ];
  return ScheduleReady(
    semester: Semester(
      id: 'agenda-semester',
      academicYear: calendar.academicYear,
      term: SemesterTerm.first,
      label: '测试学期',
      createdAt: calendar.semesterStartDate,
    ),
    engine: ScheduleEngine(
      semesterId: 'agenda-semester',
      calendarEngine: CalendarEngine(calendar),
      courses: courses,
      meetingRules: [
        for (var index = 0; index < courses.length; index++)
          MeetingRule(
            id: 'rule-$index',
            courseId: courses[index].id,
            weekday: index == 0 ? DateTime.monday : DateTime.tuesday,
            startSection: 1,
            endSection: 2,
            weekMask: WeekMask.all(8),
          ),
      ],
      exceptions: exceptions,
    ),
  );
}
