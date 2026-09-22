import 'dart:math' as math;

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
        onContainer: _bestContrastColor(base, scheme),
      );
    }
    return CourseColorPair(
      container: scheme.primary,
      onContainer: scheme.onPrimary,
    );
  }

  /// Resolves a stable, low-contrast tonal color for the dense week grid.
  ///
  /// The regular [resolve] contract is kept for the larger home/detail cards.
  /// Week cells use a palette derived from the active Material 3 scheme so a
  /// course keeps the same color across weeks and across app launches without
  /// introducing hard-coded light/dark colors.
  static CourseColorPair resolveSchedule(
    Course course,
    ColorScheme scheme,
  ) {
    if (course.colorOverride != null) {
      final base = Color(course.colorOverride!);
      return CourseColorPair(
        container: base,
        onContainer: _onColor(base, scheme),
      );
    }
    final palette = [
      scheme.primaryContainer,
      scheme.secondaryContainer,
      scheme.tertiaryContainer,
      scheme.surfaceContainerHigh,
      scheme.surfaceContainerHighest,
    ];
    final base = palette[_stableHash(course.id) % palette.length];
    return CourseColorPair(
      container: base,
      onContainer: _bestContrastColor(base, scheme),
    );
  }

  static int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  static Color _onColor(Color background, ColorScheme scheme) {
    final dark = background.computeLuminance() < 0.42;
    return dark ? scheme.onInverseSurface : scheme.onSurface;
  }

  static Color _bestContrastColor(Color background, ColorScheme scheme) {
    final candidates = [
      scheme.onSurface,
      scheme.onSurfaceVariant,
      scheme.onInverseSurface,
      scheme.onPrimary,
      scheme.onSecondary,
      scheme.onTertiary,
      scheme.onPrimaryContainer,
      scheme.onSecondaryContainer,
      scheme.onTertiaryContainer,
    ];
    return candidates.reduce(
      (best, candidate) => _contrastRatio(background, candidate) >
              _contrastRatio(background, best)
          ? candidate
          : best,
    );
  }

  static double _contrastRatio(Color background, Color foreground) {
    final lighter = math.max(
      background.computeLuminance(),
      foreground.computeLuminance(),
    );
    final darker = math.min(
      background.computeLuminance(),
      foreground.computeLuminance(),
    );
    return (lighter + .05) / (darker + .05);
  }
}
