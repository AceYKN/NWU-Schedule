import 'dart:convert';

class ScheduleDisplayPreferences {
  const ScheduleDisplayPreferences({
    required this.showWeekend,
    required this.showTeacher,
    required this.showInactiveCourses,
    required this.showPeriodTimes,
    required this.highlightCurrentPeriod,
    required this.showBackToCurrentWeekFab,
    this.hiddenCourseIds = const <String>{},
  });

  const ScheduleDisplayPreferences.defaults()
      : showWeekend = false,
        showTeacher = true,
        showInactiveCourses = false,
        showPeriodTimes = true,
        highlightCurrentPeriod = true,
        showBackToCurrentWeekFab = true,
        hiddenCourseIds = const <String>{};

  final bool showWeekend;
  final bool showTeacher;
  final bool showInactiveCourses;
  final bool showPeriodTimes;
  final bool highlightCurrentPeriod;
  final bool showBackToCurrentWeekFab;
  final Set<String> hiddenCourseIds;

  ScheduleDisplayPreferences copyWith({
    bool? showWeekend,
    bool? showTeacher,
    bool? showInactiveCourses,
    bool? showPeriodTimes,
    bool? highlightCurrentPeriod,
    bool? showBackToCurrentWeekFab,
    Set<String>? hiddenCourseIds,
  }) {
    return ScheduleDisplayPreferences(
      showWeekend: showWeekend ?? this.showWeekend,
      showTeacher: showTeacher ?? this.showTeacher,
      showInactiveCourses: showInactiveCourses ?? this.showInactiveCourses,
      showPeriodTimes: showPeriodTimes ?? this.showPeriodTimes,
      highlightCurrentPeriod:
          highlightCurrentPeriod ?? this.highlightCurrentPeriod,
      showBackToCurrentWeekFab:
          showBackToCurrentWeekFab ?? this.showBackToCurrentWeekFab,
      hiddenCourseIds: hiddenCourseIds ?? this.hiddenCourseIds,
    );
  }
}

Set<String> decodeHiddenCourseIds(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const <String>{};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <String>{};
    return Set.unmodifiable(
      decoded
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty),
    );
  } on FormatException {
    return const <String>{};
  }
}

String encodeHiddenCourseIds(Iterable<String> ids) {
  final normalized = ids
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  return jsonEncode(normalized);
}
