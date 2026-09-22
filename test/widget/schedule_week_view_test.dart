import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/schedule/effective_course_instance.dart';
import 'package:nwu_schedule/domain/schedule/week_schedule_view_model.dart';
import 'package:nwu_schedule/domain/settings/schedule_display_preferences.dart';
import 'package:nwu_schedule/features/schedule/presentation/widgets/course_block.dart';
import 'package:nwu_schedule/features/schedule/presentation/schedule_page.dart';
import 'package:nwu_schedule/features/schedule/presentation/widgets/schedule_week_grid.dart';
import 'package:nwu_schedule/features/schedule/presentation/widgets/schedule_week_display_filter.dart';
import 'package:nwu_schedule/features/shared/presentation/course_color_resolver.dart';

void main() {
  testWidgets('five and seven day grids fit a narrow phone without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final model = _model(
      entries: [
        _entry(
          id: 'weekday-course',
          name: '计算机网络',
          weekday: DateTime.monday,
          startSection: 1,
          endSection: 2,
        ),
        _entry(
          id: 'weekend-course',
          name: '周末实验课',
          weekday: DateTime.saturday,
          startSection: 3,
          endSection: 4,
        ),
      ],
    );

    await _pumpGrid(tester, model, model.days.take(5).toList());
    expect(find.text('一'), findsOneWidget);
    expect(find.text('六'), findsNothing);
    expect(find.text('计算机网络'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pumpGrid(tester, model, model.days);
    expect(find.text('六'), findsOneWidget);
    expect(find.text('周末实验课'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('course block content follows the available block height',
      (tester) async {
    final entry = _entry(
      id: 'height-course',
      name: '机器学习',
      weekday: DateTime.monday,
      startSection: 1,
      endSection: 1,
      teacher: '教师甲',
      campus: '长安校区',
      room: '3406',
    );

    await _pumpBlock(tester, entry, height: 40);
    expect(find.text('机器学习'), findsOneWidget);
    expect(find.text('长安校区\n3406'), findsOneWidget);
    expect(find.text('教师甲'), findsOneWidget);

    await _pumpBlock(tester, entry, height: 64);
    expect(find.text('机器学习'), findsOneWidget);
    expect(find.text('长安校区\n3406'), findsOneWidget);
    expect(find.text('教师甲'), findsOneWidget);

    await _pumpBlock(tester, entry, height: 128);
    expect(find.text('机器学习'), findsOneWidget);
    expect(find.text('长安校区\n3406'), findsOneWidget);
    expect(find.text('教师甲'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('course block location wraps onto every available line',
      (tester) async {
    const location = '长安校区\n教学东楼A区四层创新实验中心409室';
    final entry = _entry(
      id: 'wrapping-location-course',
      name: '机器学习',
      weekday: DateTime.monday,
      startSection: 1,
      endSection: 2,
      campus: '长安校区',
      room: '教学东楼A区四层创新实验中心409室',
    );

    await _pumpBlock(tester, entry, height: 128);

    expect(find.text(location), findsOneWidget);
    final locationText = tester.widget<Text>(find.text(location));
    expect(locationText.softWrap, isTrue);
    expect(locationText.maxLines, isNull);
    expect(tester.getSize(find.text(location)).height, greaterThan(13));
    expect(tester.takeException(), isNull);
  });

  testWidgets('only overlapping courses share the available day width',
      (tester) async {
    final model = _model(
      entries: [
        _entry(
          id: 'overlap-a',
          name: '课程 A',
          weekday: DateTime.monday,
          startSection: 1,
          endSection: 2,
        ),
        _entry(
          id: 'overlap-b',
          name: '课程 B',
          weekday: DateTime.monday,
          startSection: 1,
          endSection: 1,
        ),
        _entry(
          id: 'later-course',
          name: '后续课程',
          weekday: DateTime.monday,
          startSection: 4,
          endSection: 4,
        ),
      ],
    );

    await _pumpGrid(tester, model, model.days.take(5).toList());

    final blocks = tester.renderObjectList<RenderBox>(
      find.byType(CourseBlock),
    );
    expect(blocks, hasLength(3));
    final widths = blocks.map((box) => box.size.width).toList();
    final widest = widths.reduce((left, right) => left > right ? left : right);
    final narrowest =
        widths.reduce((left, right) => left < right ? left : right);
    expect(widest, greaterThan(narrowest * 1.5));
  });

  testWidgets('three overlapping courses collapse into an overflow affordance',
      (tester) async {
    final model = _model(
      entries: [
        _entry(
          id: 'overlap-a',
          name: '课程 A',
          weekday: DateTime.monday,
          startSection: 1,
          endSection: 2,
        ),
        _entry(
          id: 'overlap-b',
          name: '课程 B',
          weekday: DateTime.monday,
          startSection: 1,
          endSection: 2,
        ),
        _entry(
          id: 'overlap-c',
          name: '课程 C',
          weekday: DateTime.monday,
          startSection: 1,
          endSection: 2,
        ),
      ],
    );

    await _pumpGrid(tester, model, model.days.take(5).toList());

    expect(find.byType(CourseBlock), findsOneWidget);
    expect(find.byType(OverflowCourseBlock), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('current period is marked only on today column', (tester) async {
    final model = _model(
      entries: [
        _entry(
          id: 'current-course',
          name: '当前课程',
          weekday: DateTime.monday,
          startSection: 1,
          endSection: 2,
        ),
      ],
      today: DateTime.monday,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Material(
          child: SizedBox(
            width: 360,
            child: ScheduleWeekGrid(
              visibleDays: model.days.take(5).toList(),
              viewModel: model,
              preferences: const ScheduleDisplayPreferences.defaults(),
              now: DateTime(2026, 9, 7, 8, 20),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CurrentTimeIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inactive course blocks remain ghost-like and concise',
      (tester) async {
    final entry = _entry(
      id: 'inactive-course',
      name: '数据结构（实验）',
      weekday: DateTime.tuesday,
      startSection: 3,
      endSection: 4,
      teacher: '教师乙',
      room: '1310',
      active: false,
    );

    await _pumpBlock(tester, entry, height: 128);
    expect(find.text('数据结构（实验）'), findsOneWidget);
    expect(find.text('教师乙'), findsOneWidget);
    expect(find.text('1310'), findsOneWidget);
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(CourseEventCard),
            matching: find.byType(Material),
          )
          .first,
    );
    final scheme = ThemeData(useMaterial3: true).colorScheme;
    final activeColors = CourseColorResolver.resolveSchedule(
      entry.course,
      scheme,
    );
    expect(
      material.color,
      Color.lerp(scheme.surface, activeColors.container, .38),
    );
    expect(
      _contrastRatio(scheme.surface, material.color!),
      lessThan(_contrastRatio(scheme.surface, activeColors.container)),
    );
  });

  test('inactive courses are hidden by default', () {
    expect(
      const ScheduleDisplayPreferences.defaults().showInactiveCourses,
      isFalse,
    );
  });

  test('inactive entries that overlap active entries are hidden', () {
    final model = _model(
      entries: [
        _entry(
          id: 'active-course',
          name: '本周课程',
          weekday: DateTime.monday,
          startSection: 3,
          endSection: 4,
        ),
        _entry(
          id: 'conflicting-inactive-course',
          name: '冲突的非本周课程',
          weekday: DateTime.monday,
          startSection: 4,
          endSection: 5,
          active: false,
        ),
        _entry(
          id: 'visible-inactive-course',
          name: '可比较的非本周课程',
          weekday: DateTime.monday,
          startSection: 6,
          endSection: 7,
          active: false,
        ),
      ],
    );

    final filtered = ScheduleWeekDisplayFilter.hideConflictingInactive(model);

    expect(
      filtered.entries.map((entry) => entry.course.name),
      containsAll(<String>['本周课程', '可比较的非本周课程']),
    );
    expect(
      filtered.entries.map((entry) => entry.course.name),
      isNot(contains('冲突的非本周课程')),
    );
  });

  test('hidden course ids are a presentation-only filter', () {
    final model = _model(
      entries: [
        _entry(
          id: 'visible-course',
          name: '保留显示',
          weekday: DateTime.monday,
          startSection: 1,
          endSection: 2,
        ),
        _entry(
          id: 'hidden-course',
          name: '仅隐藏显示',
          weekday: DateTime.tuesday,
          startSection: 3,
          endSection: 4,
        ),
      ],
    );

    final filtered = ScheduleWeekDisplayFilter.hideCourses(
      model,
      {'hidden-course'},
    );

    expect(
        filtered.entries.map((entry) => entry.course.id), ['visible-course']);
    expect(model.entries, hasLength(2));
  });

  test('schedule course colors are stable across the week view', () {
    expect(
      CourseColorResolver.schedulePaletteLength(),
      greaterThanOrEqualTo(8),
    );
    expect(
      CourseColorResolver.schedulePaletteIndex('same-course'),
      CourseColorResolver.schedulePaletteIndex('same-course'),
    );
  });

  test('schedule course text stays neutral and meets contrast in both themes',
      () {
    final course = Course(
      id: 'contrast-course',
      semesterId: 'test-semester',
      sourceType: CourseSourceType.manual,
      name: '软件测试',
    );

    for (final brightness in Brightness.values) {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: brightness,
      );
      for (var index = 0;
          index < CourseColorResolver.schedulePaletteLength();
          index++) {
        final colors = CourseColorResolver.resolveSchedule(
          course,
          scheme,
          paletteIndex: index,
        );
        expect(
          _contrastRatio(colors.container, colors.onContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(_channelSpread(colors.onContainer), lessThanOrEqualTo(4));
      }
    }
  });

  test('weekend makeup notice takes priority over the generic course count',
      () {
    final model = _model(
      entries: [
        _entry(
          id: 'makeup-course',
          name: '周六补课',
          weekday: DateTime.saturday,
          startSection: 1,
          endSection: 2,
        ),
      ],
      dayMarkers: const {DateTime.saturday: '补'},
    );

    expect(weekendCourseNoticeMessage(model), '本周六有补课安排');
  });
}

Future<void> _pumpGrid(
  WidgetTester tester,
  WeekScheduleViewModel model,
  List<WeekDayColumn> days,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Material(
        child: SizedBox(
          width: 360,
          child: ScheduleWeekGrid(
            visibleDays: days,
            viewModel: model,
            preferences: const ScheduleDisplayPreferences.defaults(),
            now: DateTime(2026, 9, 7, 13),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpBlock(
  WidgetTester tester,
  ScheduleGridEntry entry, {
  required double height,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Material(
        child: SizedBox(
          width: 100,
          height: height,
          child: CourseBlock(
            entry: entry,
            preferences: const ScheduleDisplayPreferences.defaults(),
            width: 92,
            height: height,
            visibleDayCount: 5,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

WeekScheduleViewModel _model({
  required List<ScheduleGridEntry> entries,
  int? today,
  Map<int, String> dayMarkers = const {},
}) {
  final monday = DateTime(2026, 9, 7);
  final days = List.generate(7, (index) {
    final date = monday.add(Duration(days: index));
    return WeekDayColumn(
      weekday: date.weekday,
      date: date,
      label: '一二三四五六日'[index],
      marker: dayMarkers[date.weekday],
      isToday: date.weekday == today,
    );
  });
  return WeekScheduleViewModel(
    week: 1,
    days: days,
    entries: entries,
  );
}

ScheduleGridEntry _entry({
  required String id,
  required String name,
  required int weekday,
  required int startSection,
  required int endSection,
  String? teacher,
  String? campus,
  String? room,
  bool active = true,
}) {
  final date = DateTime(2026, 9, 7).add(Duration(days: weekday - 1));
  final course = Course(
    id: id,
    semesterId: 'test-semester',
    sourceType: CourseSourceType.manual,
    name: name,
  );
  final rule = MeetingRule(
    id: '$id-rule',
    courseId: id,
    weekday: weekday,
    startSection: startSection,
    endSection: endSection,
    teacher: teacher,
    campus: campus,
    room: room,
    weekMask: const WeekMask(1),
  );
  return ScheduleGridEntry(
    instance: EffectiveCourseInstance(
      course: course,
      meetingRule: rule,
      date: date,
      templateDate: date,
      startSection: startSection,
      endSection: endSection,
      startTime: DateTime(2026, 9, 7, 8),
      endTime: DateTime(2026, 9, 7, 9),
      teacher: teacher,
      campus: campus,
      room: room,
    ),
    active: active,
  );
}

double _contrastRatio(Color background, Color foreground) {
  final backgroundLuminance = background.computeLuminance();
  final foregroundLuminance = foreground.computeLuminance();
  final lighter = backgroundLuminance > foregroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  final darker = backgroundLuminance < foregroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + .05) / (darker + .05);
}

int _channelSpread(Color color) {
  final value = color.toARGB32();
  final channels = [
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ]..sort();
  return channels.last - channels.first;
}
