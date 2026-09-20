import 'package:flutter/material.dart';

import '../../../domain/course/course.dart';

class CourseColorPair {
  const CourseColorPair({required this.container, required this.onContainer});

  final Color container;
  final Color onContainer;
}

class CourseColorResolver {
  const CourseColorResolver._();

  static CourseColorPair resolve(Course course, ColorScheme scheme) {
    if (course.colorOverride != null) {
      final base = Color(course.colorOverride!);
      return CourseColorPair(
        container: base,
        onContainer: _onColor(base, scheme),
      );
    }
    return CourseColorPair(
      container: scheme.primary,
      onContainer: scheme.onPrimary,
    );
  }

  static Color _onColor(Color background, ColorScheme scheme) {
    final dark = background.computeLuminance() < 0.42;
    return dark ? scheme.onInverseSurface : scheme.onSurface;
  }
}
