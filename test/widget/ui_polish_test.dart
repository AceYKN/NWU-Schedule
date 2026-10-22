import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/app/bootstrap.dart';
import 'package:nwu_schedule/app/theme/schedule_theme.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/calendar/calendar_engine.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/schedule/schedule_data_repository.dart';
import 'package:nwu_schedule/domain/schedule/schedule_engine.dart';
import 'package:nwu_schedule/domain/semester/semester.dart';
import 'package:nwu_schedule/features/calendar/presentation/calendar_page.dart';
import 'package:nwu_schedule/features/home/presentation/home_page.dart';
import 'package:nwu_schedule/features/schedule/presentation/course_detail_page.dart';
import 'package:nwu_schedule/features/shared/presentation/course_card.dart';
import 'package:nwu_schedule/features/shared/presentation/course_color_resolver.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
        'semester palette survives home, month and details (dark=$dark)',
        (tester) async {
      final fixture = _Fixture();
      final theme =
          dark ? officialThemes.first.dark() : officialThemes.first.light();
      final palette = CourseColorResolver.schedulePaletteForCourses(
          fixture.snapshot.courses);
      final expected = CourseColorResolver.resolveSchedule(
        fixture.course,
        theme.colorScheme,
        paletteIndex: palette[fixture.course.id],
      );
      // A colliding name must use its assigned semester slot, not its hash.
      expect(
          palette[fixture.course.id],
          isNot(CourseColorResolver.schedulePaletteIndexForName(
              fixture.course.name)));
      final mark = find.byKey(ValueKey('course-color-${fixture.course.id}'));

      await _pump(tester, fixture, HomePage(now: fixture.now), theme: theme);
      expect(find.text('西小课'), findsNothing);
      expect(find.text('西小課'), findsNothing);
      expect(find.text('查看课表'), findsNothing);
      expect(find.text('查看課表'), findsNothing);
      expect(_markColor(tester.widget(mark)), expected.accent);
      expect(
        tester
            .widget<Card>(find.byKey(const ValueKey('home-status-card')))
            .color,
        // The original Home status card uses the theme's upcoming color.
        // Course cards and details still share the semester course palette.
        theme.colorScheme.secondaryContainer,
      );
      await tester.tap(find.byType(CourseCard));
      await tester.pumpAndSettle();
      final sheetMark =
          find.descendant(of: find.byType(BottomSheet), matching: mark);
      expect(_markColor(tester.widget(sheetMark)), expected.accent);
      expect(find.text('时间'), findsOneWidget);
      expect(find.text('地点'), findsOneWidget);
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();

      await _pump(tester, fixture, CalendarPage(now: fixture.now),
          theme: theme);
      await tester.scrollUntilVisible(mark, 100,
          scrollable: find.byType(Scrollable).first);
      expect(_markColor(tester.widget(mark)), expected.accent);
      await tester.tap(find.text(fixture.course.name));
      await tester.pumpAndSettle();
      expect(_markColor(tester.widget(sheetMark)), expected.accent);
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(
        tester,
        fixture,
        CourseDetailPage(courseId: fixture.course.id),
        theme: theme,
        textScale: 2,
      );
      expect(_markColor(tester.widget(mark)), expected.accent);
      await tester.scrollUntilVisible(find.text(fixture.room), 100,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('时间'), findsOneWidget);
      expect(find.text(fixture.teacher), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final reducedMotion in [false, true]) {
    testWidgets(
        'calendar keeps today and selection through rapid month changes '
        '(reducedMotion=$reducedMotion)', (tester) async {
      final fixture = _Fixture();
      final theme = officialThemes.first.light();
      await _pump(tester, fixture, CalendarPage(now: fixture.now),
          theme: theme, reducedMotion: reducedMotion);
      await tester.tap(find.byKey(const ValueKey('calendar-day-2026-10-20')));
      await tester.pumpAndSettle();
      BoxDecoration marker(String date) => tester
          .widget<AnimatedContainer>(
              find.byKey(ValueKey('calendar-day-marker-$date')))
          .decoration! as BoxDecoration;
      expect(marker('2026-10-19').color, Colors.transparent);
      expect(marker('2026-10-19').border!.top.color, theme.colorScheme.primary);
      expect(marker('2026-10-20').color, theme.colorScheme.primary);
      expect(find.text('10月20日  周二'), findsOneWidget);

      // Includes a five-to-six-row month change and reversing mid-animation.
      for (final tooltip in ['下个月', '上个月', '下个月', '上个月']) {
        await tester.tap(find.byTooltip(tooltip));
        await tester.pump(const Duration(milliseconds: 35));
      }
      await tester.pumpAndSettle();
      expect(find.text('10月19日  周一'), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar-day-2026-10-19')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('calendar-day-2026-12-01')), findsNothing);
      final selected = tester.widget<Semantics>(
          find.byKey(const ValueKey('calendar-day-2026-10-19')));
      expect(selected.properties.selected, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}

Color _markColor(Widget widget) => switch (widget) {
      Container(:final color, :final decoration) =>
        color ?? (decoration! as BoxDecoration).color!,
      DecoratedBox(:final decoration) => (decoration as BoxDecoration).color!,
      _ => throw StateError('Unexpected course marker: $widget'),
    };

Future<void> _pump(
  WidgetTester tester,
  _Fixture fixture,
  Widget page, {
  required ThemeData theme,
  double textScale = 1,
  bool reducedMotion = false,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(ProviderScope(
    overrides: [
      scheduleLoadProvider.overrideWith((ref) => Stream.value(fixture.ready)),
      courseSnapshotProvider(fixture.course.id)
          .overrideWith((ref) => Stream.value(fixture.snapshot)),
    ],
    child: MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
        ),
        child: child!,
      ),
      home: Scaffold(body: page),
    ),
  ));
  await tester.pumpAndSettle();
}

class _Fixture {
  _Fixture() {
    final week1 = DateTime(2026, 9, 7);
    final calendar = CalendarDefinition(
      id: 'polish',
      school: 'NWU',
      academicYear: '2026-2027',
      term: 1,
      semesterStartDate: week1,
      week1StartDate: week1,
      semesterEndDate: DateTime(2027, 1, 24),
      totalWeeks: 20,
      revision: 1,
      dateOverrides: const [],
    );
    final semester = Semester(
      id: 'polish',
      academicYear: '2026-2027',
      term: SemesterTerm.first,
      label: '2026-2027 第一学期',
      createdAt: week1,
    );
    final courses = [
      for (var index = 0; index < 14; index++)
        Course(
            id: 'course-$index',
            semesterId: semester.id,
            sourceType: CourseSourceType.manual,
            name: '课程 $index'),
    ];
    final palette = CourseColorResolver.schedulePaletteForCourses(courses);
    course = courses.firstWhere((course) =>
        palette[course.id] !=
        CourseColorResolver.schedulePaletteIndexForName(course.name));
    final rules = [
      MeetingRule(
        id: 'meeting',
        courseId: course.id,
        weekday: DateTime.monday,
        startSection: 3,
        endSection: 4,
        weekMask: WeekMask.all(20),
        room: room,
        teacher: teacher,
      ),
    ];
    snapshot = ScheduleDataSnapshot(
      semester: semester,
      courses: courses,
      meetingRules: rules,
      exceptions: const [],
    );
    ready = ScheduleReady(
      semester: semester,
      engine: ScheduleEngine(
        semesterId: semester.id,
        calendarEngine: CalendarEngine(calendar),
        courses: courses,
        meetingRules: rules,
        exceptions: const [],
      ),
    );
  }

  final now = DateTime.utc(2026, 10, 19, 1, 41);
  final room = '长安校区 · 信息科学与技术学院实验楼 3 层 321 室';
  final teacher = '授课教师甲与实验指导教师乙';
  late final Course course;
  late final ScheduleDataSnapshot snapshot;
  late final ScheduleReady ready;
}
