import 'effective_course_instance.dart';

sealed class ScheduleNowState {
  const ScheduleNowState({required this.now, required this.todayCourses});

  final DateTime now;
  final List<EffectiveCourseInstance> todayCourses;
}

final class ScheduleCurrent extends ScheduleNowState {
  const ScheduleCurrent({
    required super.now,
    required super.todayCourses,
    required this.current,
  });

  final EffectiveCourseInstance current;
}

final class ScheduleNext extends ScheduleNowState {
  const ScheduleNext({
    required super.now,
    required super.todayCourses,
    required this.next,
  });

  final EffectiveCourseInstance next;
}

final class ScheduleFinishedToday extends ScheduleNowState {
  const ScheduleFinishedToday({
    required super.now,
    required super.todayCourses,
    this.next,
  });

  final EffectiveCourseInstance? next;
}

final class ScheduleNoClassToday extends ScheduleNowState {
  const ScheduleNoClassToday({
    required super.now,
    required super.todayCourses,
    this.next,
  });

  final EffectiveCourseInstance? next;
}
