import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/calendar/calendar_definition.dart';
import 'package:nwu_schedule/domain/calendar/calendar_engine.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/course_exception.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/schedule/schedule_conflict_detector.dart';
import 'package:nwu_schedule/domain/schedule/schedule_engine.dart';

void main() {
  test('warns only when effective teaching weeks and periods overlap', () {
    final existing = _course('existing', '软件测试');
    final added = _course('added', '新课程');
    final current = _engine(
      courses: [existing],
      rules: [
        _rule('existing-rule', existing.id, 1, 1, 2, [1, 3])
      ],
    );
    expect(
      ScheduleConflictDetector.forCourseSave(
        current: current,
        changedCourses: [added],
        changedRules: [
          _rule('new-rule', added.id, 1, 2, 3, [2])
        ],
      ),
      isEmpty,
    );
    final conflicts = ScheduleConflictDetector.forCourseSave(
      current: current,
      changedCourses: [added],
      changedRules: [
        _rule('new-rule', added.id, 1, 2, 3, [3])
      ],
    );
    expect(conflicts, hasLength(1));
    expect(conflicts.single.date, DateTime(2026, 9, 21));
    expect(conflicts.single.other.courseName, '软件测试');
    expect(conflicts.single.changed.startSection, 2);
  });

  test('follows holidays and makeup-day templates', () {
    final existing = _course('existing', '软件测试');
    final added = _course('added', '新课程');
    final current = _engine(
      calendar: _calendar(overrides: [
        CalendarDateOverride(
          date: DateTime(2026, 9, 7),
          type: CalendarOverrideType.holiday,
          label: '放假',
        ),
        CalendarDateOverride(
          date: DateTime(2026, 9, 12),
          type: CalendarOverrideType.useScheduleOf,
          sourceDate: DateTime(2026, 9, 7),
          label: '补课',
        ),
      ]),
      courses: [existing],
      rules: [
        _rule('existing-rule', existing.id, 1, 1, 2, [1])
      ],
    );
    final conflicts = ScheduleConflictDetector.forCourseSave(
      current: current,
      changedCourses: [added],
      changedRules: [
        _rule('new-rule', added.id, 1, 1, 2, [1])
      ],
    );
    expect(conflicts.map((conflict) => conflict.date), [DateTime(2026, 9, 12)]);
  });

  test('does not repeat old collisions when editing unrelated course fields',
      () {
    final existing = _course('existing', '软件测试');
    final edited = _course('edited', '旧课名');
    final existingRule = _rule('existing-rule', existing.id, 1, 1, 2, [1]);
    final editedRule = _rule('edited-rule', edited.id, 1, 1, 2, [1]);
    final current = _engine(
      courses: [existing, edited],
      rules: [existingRule, editedRule],
    );
    expect(
      ScheduleConflictDetector.forCourseSave(
        current: current,
        changedCourses: [edited.copyWith(name: '新课名')],
        changedRules: [editedRule],
      ),
      isEmpty,
    );
    final noOpMove = CourseException(
      id: 'no-op-move',
      semesterId: 'semester',
      courseId: edited.id,
      sourceMeetingId: editedRule.id,
      sourceDate: DateTime(2026, 9, 7),
      type: CourseExceptionType.move,
      targetDate: DateTime(2026, 9, 7),
      targetStartSection: 1,
      targetEndSection: 2,
    );
    expect(
      ScheduleConflictDetector.forExceptionSave(
        current: current,
        exception: noOpMove,
      ),
      isEmpty,
    );
  });

  test('does not repeat an old collision when two courses are merged', () {
    final target = _course('target', '软件测试');
    final edited = _course('edited', '算法');
    final other = _course('other', '英语');
    final targetRule = _rule('target-rule', target.id, 2, 1, 2, [1]);
    final editedRule = _rule('edited-rule', edited.id, 1, 1, 2, [1]);
    final otherRule = _rule('other-rule', other.id, 1, 1, 2, [1]);
    final current = _engine(
      courses: [target, edited, other],
      rules: [targetRule, editedRule, otherRule],
    );
    expect(
      ScheduleConflictDetector.forCourseSave(
        current: current,
        changedCourses: [edited.copyWith(name: target.name), target],
        changedRules: [targetRule, editedRule],
      ),
      isEmpty,
    );
  });

  test('moving a class warns on its target date, not its removed source', () {
    final moved = _course('moved', '软件测试');
    final existing = _course('existing', '计算机网络');
    final current = _engine(
      courses: [moved, existing],
      rules: [
        _rule('moved-rule', moved.id, 1, 1, 2, [1]),
        _rule('existing-rule', existing.id, 2, 1, 2, [1]),
      ],
    );
    final move = CourseException(
      id: 'move',
      semesterId: 'semester',
      courseId: moved.id,
      sourceMeetingId: 'moved-rule',
      sourceDate: DateTime(2026, 9, 7),
      type: CourseExceptionType.move,
      targetDate: DateTime(2026, 9, 8),
      targetStartSection: 1,
      targetEndSection: 2,
    );
    final conflicts = ScheduleConflictDetector.forExceptionSave(
      current: current,
      exception: move,
    );
    expect(conflicts, hasLength(1));
    expect(conflicts.single.date, DateTime(2026, 9, 8));
    expect(conflicts.single.other.courseName, '计算机网络');
    expect(
      ScheduleConflictDetector.forExceptionSave(
        current: _engine(
          courses: [moved, existing],
          rules: current.meetingRules,
          exceptions: [move],
        ),
        exception: move,
      ),
      isEmpty,
    );
  });
}

Course _course(String id, String name) => Course(
      id: id,
      semesterId: 'semester',
      sourceType: CourseSourceType.manual,
      name: name,
    );

MeetingRule _rule(
  String id,
  String courseId,
  int weekday,
  int start,
  int end,
  List<int> weeks,
) =>
    MeetingRule(
      id: id,
      courseId: courseId,
      weekday: weekday,
      startSection: start,
      endSection: end,
      weekMask: WeekMask.fromWeeks(weeks),
    );

CalendarDefinition _calendar(
        {List<CalendarDateOverride> overrides = const []}) =>
    CalendarDefinition(
      id: 'calendar',
      school: 'NWU',
      academicYear: '2026-2027',
      term: 1,
      semesterStartDate: DateTime(2026, 9, 7),
      week1StartDate: DateTime(2026, 9, 7),
      semesterEndDate: DateTime(2026, 10, 4),
      totalWeeks: 4,
      revision: 1,
      dateOverrides: overrides,
    );

ScheduleEngine _engine({
  CalendarDefinition? calendar,
  required List<Course> courses,
  required List<MeetingRule> rules,
  List<CourseException> exceptions = const [],
}) =>
    ScheduleEngine(
      semesterId: 'semester',
      calendarEngine: CalendarEngine(calendar ?? _calendar()),
      courses: courses,
      meetingRules: rules,
      exceptions: exceptions,
    );
