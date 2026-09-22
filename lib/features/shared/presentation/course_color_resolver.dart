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

  static const _scheduleHueOffsets = [
    0.0,
    34.0,
    -34.0,
    72.0,
    -72.0,
    142.0,
    180.0,
    208.0,
    286.0,
    324.0,
  ];

  static int schedulePaletteLength() => _scheduleHueOffsets.length;

  static int schedulePaletteIndex(String courseId) {
    return _stableHash(courseId) % _scheduleHueOffsets.length;
  }

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
    ColorScheme scheme, {
    int? paletteIndex,
  }) {
    if (course.colorOverride != null) {
      final base = Color(course.colorOverride!);
      return CourseColorPair(
        container: base,
        onContainer: _neutralScheduleForeground(base, scheme),
      );
    }
    final baseHue = HSLColor.fromColor(scheme.primary).hue;
    final hueOffset = _scheduleHueOffsets[
        (paletteIndex ?? schedulePaletteIndex(course.id)) %
            _scheduleHueOffsets.length];
    final hue = ((baseHue + hueOffset) % 360 + 360) % 360;
    final tone = scheme.brightness == Brightness.light ? .86 : .30;
    final saturation = scheme.brightness == Brightness.light ? .42 : .48;
    final accent = HSLColor.fromAHSL(1, hue, saturation, tone).toColor();
    final base = Color.lerp(
      scheme.surface,
      accent,
      scheme.brightness == Brightness.light ? .72 : .78,
    )!;
    return CourseColorPair(
      container: base,
      onContainer: _neutralScheduleForeground(base, scheme),
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

  static Color _neutralScheduleForeground(
    Color background,
    ColorScheme scheme,
  ) {
    const lightForeground = Color(0xFF17181B);
    const darkForeground = Color(0xFFF3F4F6);
    final preferred = scheme.brightness == Brightness.light
        ? lightForeground
        : darkForeground;
    if (_contrastRatio(background, preferred) >= 4.5) return preferred;
    return background.computeLuminance() > .45 ? Colors.black : Colors.white;
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
