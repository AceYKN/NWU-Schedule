import 'dart:convert';

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
    required this.route,
  });

  final int id;
  final DateTime fireAtUtc;
  final String title;
  final String body;
  final String payload;
  final String route;

  Map<String, Object?> toJson() => {
        'id': id,
        'fireAtUtcMillis': fireAtUtc.toUtc().millisecondsSinceEpoch,
        'title': title,
        'body': body,
        'payload': payload,
        'route': route,
      };
}

class NotificationPlanner {
  const NotificationPlanner({this.maxRequests, this.idHash = _stableId});

  final int? maxRequests;
  final int Function(String) idHash;

  List<PlannedNotification> build({
    required ScheduleEngine engine,
    required DateTime now,
    required int leadMinutes,
    DateTime? until,
  }) {
    if (leadMinutes < 0) {
      throw ArgumentError.value(leadMinutes, 'leadMinutes');
    }
    if (maxRequests != null && maxRequests! < 1) {
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
    final dayCount = calendarDaysBetween(lastDate, firstDate);
    for (var offset = 0; offset <= dayCount; offset++) {
      final date = addCalendarDays(firstDate, offset);
      for (final instance in engine.getCoursesForDate(date)) {
        final fireAtUtc = CampusClock.campusWallTimeToUtc(
          instance.startTime.subtract(Duration(minutes: leadMinutes)),
        );
        if (!fireAtUtc.isAfter(nowUtc)) continue;
        if (until != null && fireAtUtc.isAfter(until.toUtc())) continue;
        result.add(_buildRequest(instance, fireAtUtc));
      }
    }
    // Assign in identity order so collisions do not depend on database order.
    // A rebuild replaces the entire plan, including IDs from the previous plan.
    result.sort((left, right) => left.payload.compareTo(right.payload));
    final usedIds = <int>{};
    final assigned = <PlannedNotification>[];
    for (final request in result) {
      var id = idHash(request.payload) & 0x7fffffff;
      if (id == 0) id = 1;
      while (!usedIds.add(id)) {
        id = id == 0x7fffffff ? 1 : id + 1;
      }
      assigned.add(PlannedNotification(
        id: id,
        fireAtUtc: request.fireAtUtc,
        title: request.title,
        body: request.body,
        payload: request.payload,
        route: request.route,
      ));
    }
    assigned.sort((left, right) {
      final time = left.fireAtUtc.compareTo(right.fireAtUtc);
      return time != 0 ? time : left.payload.compareTo(right.payload);
    });
    return List.unmodifiable(
      maxRequests == null ? assigned : assigned.take(maxRequests!),
    );
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
    final key = jsonEncode([
      instance.course.id,
      instance.meetingRule?.id,
      instance.exceptionId,
      dateOnly(instance.date).toIso8601String(),
      instance.startSection,
      instance.endSection,
    ]);
    return PlannedNotification(
      id: _stableId(key),
      fireAtUtc: fireAtUtc,
      title: instance.courseName,
      body: '$location · $teacher\n$start 上课',
      payload: key,
      route: '/course/${Uri.encodeComponent(instance.course.id)}',
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
