class ScheduleDisplayPreferences {
  const ScheduleDisplayPreferences({
    required this.showWeekend,
    required this.showTeacher,
    required this.showInactiveCourses,
    required this.showPeriodTimes,
    required this.highlightCurrentPeriod,
    required this.showBackToCurrentWeekFab,
  });

  const ScheduleDisplayPreferences.defaults()
      : showWeekend = false,
        showTeacher = true,
        showInactiveCourses = false,
        showPeriodTimes = true,
        highlightCurrentPeriod = true,
        showBackToCurrentWeekFab = true;

  final bool showWeekend;
  final bool showTeacher;
  final bool showInactiveCourses;
  final bool showPeriodTimes;
  final bool highlightCurrentPeriod;
  final bool showBackToCurrentWeekFab;

  ScheduleDisplayPreferences copyWith({
    bool? showWeekend,
    bool? showTeacher,
    bool? showInactiveCourses,
    bool? showPeriodTimes,
    bool? highlightCurrentPeriod,
    bool? showBackToCurrentWeekFab,
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
    );
  }
}
