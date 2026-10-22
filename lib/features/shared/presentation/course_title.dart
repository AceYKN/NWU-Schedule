import 'package:flutter/material.dart';

import '../../../domain/course/course.dart';
import 'course_color_resolver.dart';

/// Uses the same semester palette as the week grid, including custom colors.
class CourseTitle extends StatelessWidget {
  const CourseTitle({
    required this.course,
    this.paletteIndex,
    this.style,
    super.key,
  });

  final Course course;
  final int? paletteIndex;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = CourseColorResolver.resolveSchedule(
      course,
      theme.colorScheme,
      paletteIndex: paletteIndex,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 10),
          child: DecoratedBox(
            key: ValueKey('course-color-${course.id}'),
            decoration: BoxDecoration(
              color: colors.accent,
              shape: BoxShape.circle,
            ),
            child: const SizedBox.square(dimension: 10),
          ),
        ),
        Expanded(
          child: Text(
            course.name,
            style: style ??
                theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class CourseDetailLine extends StatelessWidget {
  const CourseDetailLine({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: MediaQuery.textScalerOf(context).scale(48),
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
