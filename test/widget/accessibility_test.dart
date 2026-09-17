import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/schedule/effective_course_instance.dart';
import 'package:nwu_schedule/features/shared/presentation/course_card.dart';

void main() {
  testWidgets('course card exposes its state and details to TalkBack',
      (tester) async {
    final course = Course(
      id: 'accessibility-course',
      semesterId: 'accessibility-semester',
      sourceType: CourseSourceType.manual,
      name: '软件测试',
    );
    final instance = EffectiveCourseInstance(
      course: course,
      meetingRule: MeetingRule(
        id: 'accessibility-rule',
        courseId: course.id,
        weekday: DateTime.monday,
        startSection: 3,
        endSection: 4,
        teacher: '苏老师',
        campus: '长安校区',
        room: '3406',
        weekMask: WeekMask.all(20),
      ),
      date: DateTime(2026, 9, 14),
      templateDate: DateTime(2026, 9, 14),
      startSection: 3,
      endSection: 4,
      startTime: DateTime(2026, 9, 14, 10, 10),
      endTime: DateTime(2026, 9, 14, 12),
      teacher: '苏老师',
      campus: '长安校区',
      room: '3406',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseCard(instance: instance, status: 'NEXT'),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('NEXT，软件测试，长安校区 · 3406，10:10–12:00，苏老师'),
      findsOneWidget,
    );
    expect(find.semantics.byFlag(ui.SemanticsFlag.isButton), findsWidgets);
    expect(find.semantics.byAction(ui.SemanticsAction.tap), findsWidgets);
  });
}
