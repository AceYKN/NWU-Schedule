import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Compare against the same font rasterizer used to generate the reference.
/// Windows references retain their existing paths; CI has Linux references.
class ScheduleGoldenComparator extends LocalFileComparator {
  ScheduleGoldenComparator(
    super.testFile, {
    required this.precisionTolerance,
    this.filenameTolerances = const {},
  }) : assert(precisionTolerance >= 0 && precisionTolerance <= 1);

  final double precisionTolerance;
  final Map<String, double> filenameTolerances;

  Uri _reference(Uri golden) {
    if (Platform.isLinux && golden.path.startsWith('goldens/')) {
      return golden.replace(
          path: 'goldens/linux/${golden.path.substring('goldens/'.length)}');
    }
    return golden;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) =>
      super.update(_reference(golden), imageBytes);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final reference = _reference(golden);
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(reference),
    );
    final tolerance =
        filenameTolerances[golden.pathSegments.last] ?? precisionTolerance;
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, reference, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
