import '../../core/time/campus_clock.dart';
import '../../core/utils/date_utils.dart';
import '../schedule/effective_course_instance.dart';
import '../schedule/schedule_engine.dart';

class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.fireAtUtc,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final DateTime fireAtUtc;
  final String title;
  final String body;
  final String payload;

  Map<String, Object?> toJson() => {
        'id': id,
        'fireAtUtcMillis': fireAtUtc.toUtc().millisecondsSinceEpoch,
        'title': title,
        'body': body,
        'payload': payload,
      };
}

class NotificationPlanner {
  const NotificationPlanner({this.maxRequests = 500});

  final int maxRequests;

  List<PlannedNotification> build({
    required ScheduleEngine engine,
    required DateTime now,
    required int leadMinutes,
    DateTime? until,
  }) {
    if (leadMinutes < 0) {
      throw ArgumentError.value(leadMinutes, 'leadMinutes');
    }
    if (maxRequests < 1) {
      throw ArgumentError.value(maxRequests, 'maxRequests');
    }
    final nowUtc = now.toUtc();
    final campusNow = CampusClock.toCampusWallTime(nowUtc);
    final firstDate = dateOnly(campusNow);
    final lastDate = dateOnly(
      until == null
          ? engine.calendarDefinition.semesterEndDate
          : CampusClock.toCampusWallTime(until),
    );
    if (lastDate.isBefore(firstDate)) return const [];

    final result = <PlannedNotification>[];
    final dayCount = lastDate.difference(firstDate).inDays;
    for (var offset = 0; offset <= dayCount; offset++) {
      final date = firstDate.add(Duration(days: offset));
      for (final instance in engine.getCoursesForDate(date)) {
        final fireAtUtc = CampusClock.campusWallTimeToUtc(
          instance.startTime.subtract(Duration(minutes: leadMinutes)),
        );
        if (!fireAtUtc.isAfter(nowUtc)) continue;
        if (until != null && fireAtUtc.isAfter(until.toUtc())) continue;
        result.add(_buildRequest(instance, fireAtUtc));
        if (result.length >= maxRequests) {
          return List.unmodifiable(result);
        }
      }
    }
    result.sort((left, right) => left.fireAtUtc.compareTo(right.fireAtUtc));
    return List.unmodifiable(result);
  }

  PlannedNotification _buildRequest(
    EffectiveCourseInstance instance,
    DateTime fireAtUtc,
  ) {
    final location = instance.location ?? '地点待定';
    final teacher = instance.teacher?.trim().isNotEmpty == true
        ? instance.teacher!.trim()
        : '教师待定';
    final start = _formatTime(instance.startTime);
    final key = [
      instance.course.id,
      instance.meetingRule?.id ?? 'exception',
      dateOnly(instance.date).toIso8601String(),
      instance.startSection,
      instance.endSection,
    ].join('|');
    return PlannedNotification(
      id: _stableId(key),
      fireAtUtc: fireAtUtc,
      title: instance.courseName,
      body: '$location · $teacher\n$start 上课',
      payload: key,
    );
  }

  static int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  static String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
