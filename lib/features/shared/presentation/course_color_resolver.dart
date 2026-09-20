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
      final hsl = HSLColor.fromColor(base);
      final lightness = scheme.brightness == Brightness.dark ? 0.28 : 0.88;
      final container = hsl
          .withSaturation((hsl.saturation * 0.72).clamp(0.18, 0.72))
          .withLightness(lightness)
          .toColor();
      return CourseColorPair(
        container: container,
        onContainer: _onColor(container, scheme),
      );
    }
    final palette = [
      scheme.primaryContainer,
      scheme.secondaryContainer,
      scheme.tertiaryContainer,
      Color.alphaBlend(scheme.primary.withAlpha(24), scheme.surfaceContainer),
    ];
    final index = _stableHash('${course.id}:${course.name}') % palette.length;
    final container = palette[index];
    return CourseColorPair(
      container: container,
      onContainer: _onColor(container, scheme),
    );
  }

  static Color _onColor(Color background, ColorScheme scheme) {
    final dark = background.computeLuminance() < 0.42;
    return dark ? scheme.onInverseSurface : scheme.onSurface;
  }

  static int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
