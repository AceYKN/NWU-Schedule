import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/course/course.dart';
import '../../../domain/course/course_identity.dart';

class CourseColorPair {
  const CourseColorPair({required this.container, required this.onContainer});

  final Color container;
  final Color onContainer;
}

class CourseColorResolver {
  const CourseColorResolver._();

  // Twelve hue families. The next twelve tokens revisit them at different
  // tones. The LCh tones are checked for separation and contrast in all six
  // official theme states by schedule_palette_test.dart.
  static const _scheduleHues = <double>[
    250,
    70,
    160,
    340,
    100,
    280,
    190,
    10,
    130,
    310,
    220,
    40,
  ];
  static const _lightTones = <(double, double)>[
    (90, 16),
    (90, 19),
    (89, 24),
    (87, 24),
    (94, 6),
    (82, 24),
    (82, 13),
    (82, 11),
    (82, 17),
    (92, 15),
    (83, 24),
    (82, 24),
    (82, 24),
    (82, 11),
    (92, 13),
    (94, 6),
    (84, 24),
    (82, 7),
    (95, 23),
    (82, 24),
    (95, 24),
    (83, 24),
    (93, 7),
    (91, 12),
  ];
  static const _darkTones = <(double, double)>[
    (26, 22),
    (16, 24),
    (19, 24),
    (18, 24),
    (21, 10),
    (12, 16),
    (11, 13),
    (26, 22),
    (11, 18),
    (26, 24),
    (26, 6),
    (12, 13),
    (14, 5),
    (26, 18),
    (23, 13),
    (23, 11),
    (21, 24),
    (22, 24),
    (26, 20),
    (12, 24),
    (26, 24),
    (12, 24),
    (20, 16),
    (21, 24),
  ];

  static int schedulePaletteLength() => _lightTones.length;

  static int schedulePaletteIndexForName(String courseName) {
    return _stableHash(CourseIdentity.nameKey(courseName)) %
        _scheduleHues.length;
  }

  /// Assigns distinct automatic colors to the courses in one semester.
  /// Sorting makes the result independent of repository and week entry order.
  /// Extra courses receive new color indices after the base palette is full.
  static Map<String, int> schedulePaletteForCourses(Iterable<Course> courses) {
    final automatic = courses
        .where((course) => !course.deleted && course.colorOverride == null)
        .toList();
    final identities = automatic
        .map((course) => CourseIdentity.nameKey(course.name))
        .toSet()
        .toList()
      ..sort();
    final slotsByIdentity = <String, int>{};
    final assigned = <String, int>{};
    final used = <int>{};
    for (final identity in identities) {
      final base = _stableHash(identity) % _scheduleHues.length;
      var index = -1;
      for (var tier = 0; tier < 2 && index < 0; tier++) {
        for (var probe = 0; probe < _scheduleHues.length; probe++) {
          final candidate = tier * _scheduleHues.length +
              (base + probe * 5) % _scheduleHues.length;
          if (!used.contains(candidate)) {
            index = candidate;
            break;
          }
        }
      }
      if (index < 0) index = used.length;
      slotsByIdentity[identity] = index;
      used.add(index);
    }
    for (final course in automatic) {
      assigned[course.id] =
          slotsByIdentity[CourseIdentity.nameKey(course.name)]!;
    }
    return assigned;
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
  /// Hue family stays fixed across themes; brightness selects a muted LCh tone
  /// and the current scheme's surface supplies the final theme tint.
  static CourseColorPair resolveSchedule(
    Course course,
    ColorScheme scheme, {
    int? paletteIndex,
  }) {
    final index = paletteIndex ?? schedulePaletteIndexForName(course.name);
    final light = scheme.brightness == Brightness.light;
    final tones = light ? _lightTones : _darkTones;
    final (double lightness, double chroma) = course.colorOverride != null
        ? (light ? (88, 20) : (22, 20))
        : index < schedulePaletteLength()
            ? tones[index]
            : (light
                ? (84.0 + (index % 4) * 3, 14.0 + (index % 3) * 7)
                : (14.0 + (index % 4) * 4, 14.0 + (index % 3) * 7));
    final hue = course.colorOverride != null
        ? _lchHueOf(Color(course.colorOverride!))
        : index < schedulePaletteLength()
            ? _scheduleHues[index % _scheduleHues.length]
            : ((index - schedulePaletteLength()) * 137.507764) % 360;
    final accent = _lchColor(lightness, chroma, hue);
    final base = Color.lerp(scheme.surface, accent, .90)!;
    return CourseColorPair(
      container: base,
      onContainer: _neutralScheduleForeground(base, scheme),
    );
  }

  static double _lchHueOf(Color color) {
    final argb = color.toARGB32();
    double linear(int shift) {
      final channel = ((argb >> shift) & 0xff) / 255;
      return channel <= .04045
          ? channel / 12.92
          : math.pow((channel + .055) / 1.055, 2.4).toDouble();
    }

    final red = linear(16);
    final green = linear(8);
    final blue = linear(0);
    final x = (.4124564 * red + .3575761 * green + .1804375 * blue) / .95047;
    final y = .2126729 * red + .7151522 * green + .0721750 * blue;
    final z = (.0193339 * red + .1191920 * green + .9503041 * blue) / 1.08883;
    double lab(double value) => value > .008856
        ? math.pow(value, 1 / 3).toDouble()
        : value / (3 * math.pow(6 / 29, 2)) + 4 / 29;
    final fy = lab(y);
    final a = 500 * (lab(x) - fy);
    final b = 200 * (fy - lab(z));
    return (math.atan2(b, a) * 180 / math.pi + 360) % 360;
  }

  // CIE LCh gives the muted palette a measurable separation after surface
  // mixing. Reduce chroma only if a user's custom hue falls outside sRGB.
  static Color _lchColor(double lightness, double chroma, double hue) {
    for (var candidateChroma = chroma;
        candidateChroma >= 0;
        candidateChroma -= 1) {
      final radians = hue * math.pi / 180;
      final a = candidateChroma * math.cos(radians);
      final b = candidateChroma * math.sin(radians);
      final fy = (lightness + 16) / 116;
      final fx = fy + a / 500;
      final fz = fy - b / 200;
      double inverseLab(double value) => value > 6 / 29
          ? value * value * value
          : 3 * math.pow(6 / 29, 2).toDouble() * (value - 4 / 29);
      final x = .95047 * inverseLab(fx);
      final y = inverseLab(fy);
      final z = 1.08883 * inverseLab(fz);
      final linear = [
        3.2404542 * x - 1.5371385 * y - .4985314 * z,
        -.969266 * x + 1.8760108 * y + .041556 * z,
        .0556434 * x - .2040259 * y + 1.0572252 * z,
      ];
      if (linear.any((channel) => channel < 0 || channel > 1)) continue;
      int channel(double value) {
        final srgb = value <= .0031308
            ? 12.92 * value
            : 1.055 * math.pow(value, 1 / 2.4) - .055;
        return (srgb * 255).round().clamp(0, 255);
      }

      return Color.fromARGB(
        255,
        channel(linear[0]),
        channel(linear[1]),
        channel(linear[2]),
      );
    }
    return Color.fromARGB(255, 128, 128, 128);
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
    const lightForeground = Color(0xFF3B3C3F);
    const darkForeground = Color(0xFFF3F4F6);
    final preferred = scheme.brightness == Brightness.light
        ? lightForeground
        : darkForeground;
    if (_contrastRatio(background, preferred) >= 4.5) return preferred;
    return _contrastRatio(background, Colors.black) >=
            _contrastRatio(background, Colors.white)
        ? Colors.black
        : Colors.white;
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
