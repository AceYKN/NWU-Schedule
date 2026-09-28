import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/app/theme/schedule_theme.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/calendar/calendar_engine.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/schedule/schedule_engine.dart';
import 'package:nwu_schedule/features/schedule/presentation/widgets/course_block.dart';
import 'package:nwu_schedule/features/schedule/presentation/widgets/schedule_week_grid.dart';
import 'package:nwu_schedule/features/shared/presentation/course_color_resolver.dart';
import 'package:nwu_schedule/domain/settings/schedule_display_preferences.dart';

import '../helpers/color_metrics.dart';
import '../helpers/schedule_palette_fixture.dart';

void main() {
  test('identity allocation is stable, unique, and shared by same names', () {
    final courses = [
      for (var index = 0; index < 40; index++)
        Course(
          id: 'course-$index',
          semesterId: 'term',
          sourceType: CourseSourceType.manual,
          name: '逻辑课程 $index',
        ),
      Course(
        id: 'duplicate',
        semesterId: 'term',
        sourceType: CourseSourceType.manual,
        name: ' 逻辑课程 0\u00a0',
      ),
    ];
    final palette = CourseColorResolver.schedulePaletteForCourses(courses);
    expect(palette,
        CourseColorResolver.schedulePaletteForCourses(courses.reversed));
    expect(palette['duplicate'], palette['course-0']);
    expect(palette.values.toSet(), hasLength(40));
    expect(palette.values.where((slot) => slot < 12).length, 13);
    for (final theme in officialThemes) {
      for (final scheme in [
        theme.light().colorScheme,
        theme.dark().colorScheme
      ]) {
        final colors = courses
            .take(40)
            .map((course) => CourseColorResolver.resolveSchedule(course, scheme,
                    paletteIndex: palette[course.id])
                .container)
            .toSet();
        expect(colors, hasLength(40),
            reason: '${theme.id} ${scheme.brightness}');
        for (final course in courses.take(40)) {
          final pair = CourseColorResolver.resolveSchedule(course, scheme,
              paletteIndex: palette[course.id]);
          expect(colorContrast(pair.container, pair.onContainer),
              greaterThanOrEqualTo(4.5));
          expect(
              colorContrast(scheme.surface, pair.container),
              lessThanOrEqualTo(
                  scheme.brightness == Brightness.light ? 1.5 : 1.65));
        }
      }
    }
  });

  test('multiple meetings and teaching weeks keep one course color', () {
    final course = Course(
      id: 'software-one',
      semesterId: 'term',
      sourceType: CourseSourceType.manual,
      name: '软件测试',
    );
    final sameName = Course(
      id: 'software-two',
      semesterId: 'term',
      sourceType: CourseSourceType.manual,
      name: ' 软件测试\u00a0',
    );
    final engine = ScheduleEngine(
      semesterId: 'term',
      calendarEngine: CalendarEngine(CalendarDefinition(
        id: 'term',
        school: 'NWU',
        academicYear: '2026-2027',
        term: 1,
        semesterStartDate: DateTime(2026, 9, 7),
        week1StartDate: DateTime(2026, 9, 7),
        semesterEndDate: DateTime(2027, 1, 24),
        totalWeeks: 20,
        revision: 1,
        dateOverrides: const [],
      )),
      courses: [course, sameName],
      meetingRules: [
        MeetingRule(
          id: 'monday',
          courseId: course.id,
          weekday: DateTime.monday,
          startSection: 1,
          endSection: 2,
          weekMask: WeekMask.all(20),
        ),
        MeetingRule(
          id: 'friday',
          courseId: course.id,
          weekday: DateTime.friday,
          startSection: 5,
          endSection: 6,
          weekMask: WeekMask.all(20),
        ),
        MeetingRule(
          id: 'second-id',
          courseId: sameName.id,
          weekday: DateTime.tuesday,
          startSection: 3,
          endSection: 4,
          weekMask: WeekMask.all(20),
        ),
      ],
      exceptions: const [],
    );
    final palette =
        CourseColorResolver.schedulePaletteForCourses(engine.courses);
    expect(palette[course.id], palette[sameName.id]);
    final scheme = officialThemes.first.light().colorScheme;
    final colors = <Color>{};
    for (final week in [1, 5]) {
      final model = engine.getWeekViewModel(week);
      expect(model.entries, hasLength(3));
      for (final entry in model.entries) {
        colors.add(CourseColorResolver.resolveSchedule(entry.course, scheme,
                paletteIndex: palette[entry.course.id])
            .container);
      }
    }
    expect(colors, hasLength(1));
  });

  test('palette separation and contrast hold in all official themes', () {
    var firstMin = double.infinity;
    var allMin = double.infinity;
    var backgroundMax = 0.0;
    var textMin = double.infinity;
    final course = paletteCourse(0);
    for (final theme in officialThemes) {
      for (final scheme in [
        theme.light().colorScheme,
        theme.dark().colorScheme
      ]) {
        final pairs = [
          for (var index = 0; index < 24; index++)
            CourseColorResolver.resolveSchedule(course, scheme,
                paletteIndex: index),
        ];
        for (var index = 0; index < pairs.length; index++) {
          final background =
              colorContrast(scheme.surface, pairs[index].container);
          final text =
              colorContrast(pairs[index].container, pairs[index].onContainer);
          backgroundMax = math.max(backgroundMax, background);
          textMin = math.min(textMin, text);
          expect(
              background,
              lessThanOrEqualTo(
                  scheme.brightness == Brightness.light ? 1.50 : 1.65),
              reason: '${theme.id} ${scheme.brightness} token $index');
          expect(text, greaterThanOrEqualTo(4.5));
          for (var other = 0; other < index; other++) {
            final distance =
                deltaE76(pairs[index].container, pairs[other].container);
            allMin = math.min(allMin, distance);
            if (index < 12) firstMin = math.min(firstMin, distance);
            expect(distance, greaterThanOrEqualTo(index < 12 ? 12 : 8),
                reason: '${theme.id} ${scheme.brightness} $other/$index');
          }
        }
      }
    }
    // ignore: avoid_print
    print('palette metrics: first12 ΔE=$firstMin all24 ΔE=$allMin '
        'max surface contrast=$backgroundMax min text contrast=$textMin');
  });

  test('manual hue is softened in both brightnesses', () {
    final course = Course(
      id: 'override',
      semesterId: 'term',
      sourceType: CourseSourceType.manual,
      name: '自选紫色',
      colorOverride: 0xff7a46a1,
    );
    for (final theme in officialThemes) {
      for (final scheme in [
        theme.light().colorScheme,
        theme.dark().colorScheme
      ]) {
        final pair = CourseColorResolver.resolveSchedule(course, scheme);
        expect(pair.container, isNot(const Color(0xff7a46a1)));
        expect(
            colorContrast(scheme.surface, pair.container),
            lessThanOrEqualTo(
                scheme.brightness == Brightness.light ? 1.5 : 1.65));
        expect(colorContrast(pair.container, pair.onContainer),
            greaterThanOrEqualTo(4.5));
        final sourceHue = HSLColor.fromColor(const Color(0xff7a46a1)).hue;
        final resultHue = HSLColor.fromColor(pair.container).hue;
        final difference = (sourceHue - resultHue).abs();
        expect(math.min(difference, 360 - difference), lessThan(45));
      }
    }
    expect(
        CourseColorResolver.resolve(
                course, officialThemes.first.light().colorScheme)
            .container,
        const Color(0xff7a46a1));
  });

  testWidgets('real week grid paints distinct courses and shared name alike',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final model = paletteWeekModel();
    final palette = CourseColorResolver.schedulePaletteForCourses(
        model.entries.map((entry) => entry.course));
    await tester.pumpWidget(MaterialApp(
      theme: officialThemes.first.light(),
      home: Scaffold(
          body: ScheduleWeekGrid(
        visibleDays: model.days,
        viewModel: model,
        preferences: const ScheduleDisplayPreferences.defaults(),
        now: DateTime(2026, 9, 7, 8, 20),
        coursePalette: palette,
      )),
    ));
    await tester.pumpAndSettle();
    final byName = <String, Color>{};
    for (final element in find.byType(CourseEventCard).evaluate()) {
      final card = element.widget as CourseEventCard;
      final color = tester
          .widget<Material>(find
              .descendant(
                  of: find.byWidget(card), matching: find.byType(Material))
              .first)
          .color!;
      if (!card.entry.active) continue;
      final name = card.entry.course.name.trim();
      if (byName.containsKey(name)) {
        expect(color, byName[name]);
      } else {
        byName[name] = color;
      }
    }
    expect(byName, hasLength(12));
    final colors = byName.values.toList();
    for (var i = 0; i < colors.length; i++) {
      for (var j = 0; j < i; j++) {
        expect(deltaE76(colors[i], colors[j]), greaterThanOrEqualTo(12));
      }
    }
  });
}
