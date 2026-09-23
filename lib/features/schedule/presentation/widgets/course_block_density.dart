enum CourseBlockDensity { roomy, compact, dense }

CourseBlockDensity resolveCourseBlockDensity({
  required double width,
  required double height,
  required int visibleDayCount,
}) {
  if (width < 56 || visibleDayCount >= 7) {
    return CourseBlockDensity.dense;
  }

  if (width < 72 || height < 70) {
    return CourseBlockDensity.compact;
  }

  return CourseBlockDensity.roomy;
}
