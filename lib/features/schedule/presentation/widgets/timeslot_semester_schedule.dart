import '../../../../core/utils/date_utils.dart';
import '../../../../domain/course/course_exception.dart';
import '../../../../domain/schedule/effective_course_instance.dart';
import '../../../../domain/schedule/schedule_engine.dart';

/// The effective arrangements found at one exact weekday/period range over
/// the whole semester. This is presentation data: the engine remains the
/// only source of truth for each week's effective instances.
class TimeslotSemesterSchedule {
  const TimeslotSemesterSchedule({
    required this.weekday,
    required this.startSection,
    required this.endSection,
    required this.groups,
  });

  final int weekday;
  final int startSection;
  final int endSection;
  final List<TimeslotWeekGroup> groups;
}

class TimeslotWeekGroup {
  TimeslotWeekGroup({
    required Iterable<int> weeks,
    required Iterable<EffectiveCourseInstance> meetings,
    this.statusLabel,
  })  : weeks = List.unmodifiable(weeks),
        meetings = List.unmodifiable(meetings);

  final List<int> weeks;
  final List<EffectiveCourseInstance> meetings;
  final String? statusLabel;

  bool containsWeek(int week) => weeks.contains(week);

  String get weekLabel => _formatTimeslotWeeks(weeks);

  bool get isEmpty => meetings.isEmpty;
}

class TimeslotSemesterScheduleBuilder {
  const TimeslotSemesterScheduleBuilder._();

  static TimeslotSemesterSchedule build({
    required ScheduleEngine engine,
    required int weekday,
    required int startSection,
    required int endSection,
  }) {
    final drafts = <_GroupDraft>[];
    for (var week = 1; week <= engine.totalWeeks; week++) {
      final entries = engine
          .getWeekViewModel(week)
          .entries
          .where(
            (entry) =>
                entry.weekday == weekday &&
                entry.startSection == startSection &&
                entry.endSection == endSection,
          )
          .toList(growable: false);
      final statusLabel = entries.isEmpty
          ? _exceptionGapLabel(
              engine,
              week: week,
              weekday: weekday,
              startSection: startSection,
              endSection: endSection,
            )
          : null;
      if (entries.isEmpty && statusLabel == null) continue;

      final meetings =
          entries.map((entry) => entry.instance).toList(growable: false);
      final key = _arrangementKey(meetings, statusLabel);
      final previous = drafts.isEmpty ? null : drafts.last;
      if (previous != null && previous.key == key) {
        previous.weeks.add(week);
      } else {
        drafts.add(
          _GroupDraft(
            key: key,
            weeks: [week],
            meetings: meetings,
            statusLabel: statusLabel,
          ),
        );
      }
    }

    return TimeslotSemesterSchedule(
      weekday: weekday,
      startSection: startSection,
      endSection: endSection,
      groups: [
        for (final draft in drafts)
          TimeslotWeekGroup(
            weeks: draft.weeks,
            meetings: draft.meetings,
            statusLabel: draft.statusLabel,
          ),
      ],
    );
  }

  static String _arrangementKey(
    List<EffectiveCourseInstance> meetings,
    String? statusLabel,
  ) {
    if (meetings.isEmpty) return 'gap:$statusLabel';
    final values = meetings.map((meeting) {
      final ruleId = meeting.meetingRule?.id ?? '';
      return [
        meeting.course.id,
        meeting.course.name,
        ruleId,
        meeting.teacher ?? '',
        meeting.campus ?? '',
        meeting.room ?? '',
        meeting.isException ? 'exception' : 'regular',
        meeting.exceptionType?.name ?? '',
      ].join('\u001f');
    }).toList()
      ..sort();
    return values.join('\u001e');
  }

  static String? _exceptionGapLabel(
    ScheduleEngine engine, {
    required int week,
    required int weekday,
    required int startSection,
    required int endSection,
  }) {
    final date = dateOnly(
      engine.weekStart(week).add(Duration(days: weekday - DateTime.monday)),
    );
    for (final exception in engine.exceptions) {
      if (exception.sourceDate == null ||
          !isSameDate(exception.sourceDate!, date) ||
          (exception.type != CourseExceptionType.cancel &&
              exception.type != CourseExceptionType.move)) {
        continue;
      }
      final sourceRule = engine.meetingRules.where((rule) {
        if (exception.sourceMeetingId != null &&
            rule.id != exception.sourceMeetingId) {
          return false;
        }
        if (exception.courseId != null && rule.courseId != exception.courseId) {
          return false;
        }
        return rule.weekday == weekday &&
            rule.startSection == startSection &&
            rule.endSection == endSection &&
            rule.includesWeek(week);
      });
      if (sourceRule.isNotEmpty) {
        return exception.type == CourseExceptionType.cancel ? '停课' : '调课';
      }
    }
    return null;
  }
}

class _GroupDraft {
  _GroupDraft({
    required this.key,
    required this.weeks,
    required this.meetings,
    required this.statusLabel,
  });

  final String key;
  final List<int> weeks;
  final List<EffectiveCourseInstance> meetings;
  final String? statusLabel;
}

String _formatTimeslotWeeks(List<int> weeks) {
  if (weeks.isEmpty) return '无教学周';
  if (weeks.length == 1) return '${weeks.single}周';
  final step = weeks[1] - weeks[0];
  if ((step == 1 || step == 2) &&
      weeks.every((week) => week == weeks.first + step * weeks.indexOf(week))) {
    final suffix = step == 2 ? (weeks.first.isOdd ? '单周' : '双周') : '';
    return '${weeks.first}-${weeks.last}周$suffix';
  }

  final ranges = <String>[];
  var start = weeks.first;
  var end = start;
  for (final week in weeks.skip(1)) {
    if (week == end + 1) {
      end = week;
      continue;
    }
    ranges.add(start == end ? '$start' : '$start-$end');
    start = week;
    end = week;
  }
  ranges.add(start == end ? '$start' : '$start-$end');
  return '${ranges.join(',')}周';
}
