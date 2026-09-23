import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/schedule/effective_course_instance.dart';
import 'package:nwu_schedule/domain/schedule/week_schedule_view_model.dart';
import 'package:nwu_schedule/domain/settings/schedule_display_preferences.dart';
import 'package:nwu_schedule/features/schedule/presentation/widgets/course_block.dart';

void main() {
  testWidgets('seven day card gives room priority over campus and teacher',
      (tester) async {
    await _pumpBlock(
      tester,
      campus: '长安校区',
      room: '3406',
      teacher: '教师甲',
    );

    expect(find.text('机器学习'), findsOneWidget);
    expect(find.text('3406'), findsOneWidget);
    expect(find.text('长安校区'), findsNothing);
    expect(find.text('教师甲'), findsNothing);
    expect(
      tester.widget<Text>(find.text('机器学习')).style?.fontSize,
      greaterThanOrEqualTo(11),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('seven day card uses campus when room is absent', (tester) async {
    await _pumpBlock(tester, campus: '太白校区', teacher: '教师乙');

    expect(find.text('太白校区'), findsOneWidget);
    expect(find.text('教师乙'), findsNothing);
  });
}

Future<void> _pumpBlock(
  WidgetTester tester, {
  String? campus,
  String? room,
  String? teacher,
}) async {
  final course = Course(
    id: 'dense-course',
    semesterId: 'test-semester',
    sourceType: CourseSourceType.manual,
    name: '机器学习',
  );
  final date = DateTime(2026, 9, 7);
  final rule = MeetingRule(
    id: 'dense-course-rule',
    courseId: course.id,
    weekday: DateTime.monday,
    startSection: 1,
    endSection: 2,
    teacher: teacher,
    campus: campus,
    room: room,
    weekMask: const WeekMask(1),
  );
  final entry = ScheduleGridEntry(
    instance: EffectiveCourseInstance(
      course: course,
      meetingRule: rule,
      date: date,
      templateDate: date,
      startSection: 1,
      endSection: 2,
      startTime: DateTime(2026, 9, 7, 8),
      endTime: DateTime(2026, 9, 7, 9),
      teacher: teacher,
      campus: campus,
      room: room,
    ),
    active: true,
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Material(
        child: SizedBox(
          width: 100,
          height: 128,
          child: CourseBlock(
            entry: entry,
            preferences: const ScheduleDisplayPreferences.defaults(),
            width: 92,
            height: 128,
            visibleDayCount: 7,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
