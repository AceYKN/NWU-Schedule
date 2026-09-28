import 'dart:math' as math;

import 'package:flutter/material.dart';

double colorContrast(Color a, Color b) {
  final high = math.max(a.computeLuminance(), b.computeLuminance());
  final low = math.min(a.computeLuminance(), b.computeLuminance());
  return (high + .05) / (low + .05);
}

double deltaE76(Color first, Color second) {
  final a = _lab(first);
  final b = _lab(second);
  return math.sqrt(
    math.pow(a[0] - b[0], 2) +
        math.pow(a[1] - b[1], 2) +
        math.pow(a[2] - b[2], 2),
  );
}

List<double> _lab(Color color) {
  final argb = color.toARGB32();
  double linear(int shift) {
    final value = ((argb >> shift) & 0xff) / 255;
    return value <= .04045
        ? value / 12.92
        : math.pow((value + .055) / 1.055, 2.4).toDouble();
  }

  final r = linear(16);
  final g = linear(8);
  final b = linear(0);
  final x = (.4124564 * r + .3575761 * g + .1804375 * b) / .95047;
  final y = .2126729 * r + .7151522 * g + .0721750 * b;
  final z = (.0193339 * r + .1191920 * g + .9503041 * b) / 1.08883;
  double transform(double value) => value > .008856
      ? math.pow(value, 1 / 3).toDouble()
      : value / (3 * math.pow(6 / 29, 2)) + 4 / 29;
  final fx = transform(x);
  final fy = transform(y);
  final fz = transform(z);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}
