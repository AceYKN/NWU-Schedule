import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/course_exception.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';

void main() {
  Course makeCourse({String name = '软件测试'}) => Course(
        id: 'course-1',
        semesterId: 'semester-1',
        sourceType: CourseSourceType.manual,
        name: name,
        note: '原备注',
        colorOverride: 0xff123456,
      );

  MeetingRule makeRule({int weekday = 1, int start = 3, int end = 4}) =>
      MeetingRule(
        id: 'rule-1',
        courseId: 'course-1',
        weekday: weekday,
        startSection: start,
        endSection: end,
        teacher: '原教师',
        weekMask: WeekMask.all(16),
      );

  test('course names validate and nullable fields can clear', () {
    expect(() => makeCourse(name: '  '), throwsArgumentError);
    final course = makeCourse();
    expect(course.copyWith(note: null, colorOverride: null).note, isNull);
    expect(
        course.copyWith(note: null, colorOverride: null).colorOverride, isNull);
    expect(course.copyWith().note, '原备注');
  });

  test('copying local fields preserves course creation time', () {
    final createdAt = DateTime.utc(2026, 9, 1, 8);
    final updatedAt = DateTime.utc(2026, 9, 1, 9);
    final course = Course(
      id: 'course-1',
      semesterId: 'semester-1',
      sourceType: CourseSourceType.manual,
      name: '软件测试',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final nextUpdatedAt = DateTime.utc(2026, 9, 1, 10);
    final updated = course.copyWith(
      colorOverride: 0xff123456,
      hidden: true,
      updatedAt: nextUpdatedAt,
    );

    expect(updated.createdAt, createdAt);
    expect(updated.updatedAt, nextUpdatedAt);
  });

  test('meeting rules enforce section and weekday bounds', () {
    expect(() => makeRule(weekday: 8), throwsArgumentError);
    expect(() => makeRule(start: 5, end: 4), throwsArgumentError);
    expect(() => makeRule(end: 12), throwsArgumentError);
    expect(makeRule().copyWith(teacher: null).teacher, isNull);
  });

  test('exceptions reject missing required fields', () {
    expect(
      () => CourseException(
        id: 'move',
        semesterId: 'semester-1',
        type: CourseExceptionType.move,
      ),
      throwsArgumentError,
    );
    expect(
      () => CourseException(
        id: 'add',
        semesterId: 'semester-1',
        type: CourseExceptionType.add,
        targetDate: DateTime(2026, 9, 7),
        targetStartSection: 5,
        targetEndSection: 6,
      ),
      throwsArgumentError,
    );
    expect(
      () => CourseException(
        id: 'cancel',
        semesterId: 'semester-1',
        courseId: 'course-1',
        sourceMeetingId: 'rule-1',
        sourceDate: DateTime(2026, 9, 7),
        type: CourseExceptionType.cancel,
        targetStartSection: 3,
      ),
      throwsArgumentError,
    );
  });
}
