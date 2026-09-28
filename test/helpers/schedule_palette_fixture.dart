import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/schedule/effective_course_instance.dart';
import 'package:nwu_schedule/domain/schedule/week_schedule_view_model.dart';

const paletteCourseNames = [
  '数据结构',
  '机器学习',
  '软件测试',
  'Web 数据挖掘',
  '形式语言与自动机',
  '大学英语',
  '操作系统',
  '计算机网络',
  '数据库',
  '算法设计',
  '编译原理',
  '离散数学',
];

Course paletteCourse(int index, {String? name}) => Course(
      id: 'palette-$index',
      semesterId: 'palette-semester',
      sourceType: CourseSourceType.manual,
      name: name ?? paletteCourseNames[index],
    );

WeekScheduleViewModel paletteWeekModel() {
  final monday = DateTime(2026, 9, 7);
  final days = List.generate(5, (index) {
    final date = monday.add(Duration(days: index));
    return WeekDayColumn(
      weekday: date.weekday,
      date: date,
      label: '一二三四五'[index],
      kind: ScheduleDayKind.normal,
      isToday: index == 0,
    );
  });
  ScheduleGridEntry entry(Course course, int day, int section,
      {bool active = true}) {
    final date = monday.add(Duration(days: day));
    final rule = MeetingRule(
      id: '${course.id}-$day-$section',
      courseId: course.id,
      weekday: date.weekday,
      startSection: section,
      endSection: section + 1,
      room: '教学楼 ${101 + day}',
      weekMask: const WeekMask(1),
    );
    return ScheduleGridEntry(
      instance: EffectiveCourseInstance(
        course: course,
        meetingRule: rule,
        date: date,
        templateDate: date,
        startSection: section,
        endSection: section + 1,
        startTime: date.add(const Duration(hours: 8)),
        endTime: date.add(const Duration(hours: 9)),
        room: rule.room,
      ),
      active: active,
    );
  }

  return WeekScheduleViewModel(week: 1, days: days, entries: [
    for (var index = 0; index < paletteCourseNames.length; index++)
      entry(paletteCourse(index), index % 5, 1 + (index ~/ 5) * 3),
    entry(paletteCourse(12, name: ' 软件测试\u00a0'), 4, 10),
    entry(paletteCourse(13, name: '数据库'), 3, 10, active: false),
  ]);
}
