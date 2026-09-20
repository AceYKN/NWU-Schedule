import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/app/theme/schedule_theme.dart';
import 'package:nwu_schedule/domain/import/import_diff.dart';
import 'package:nwu_schedule/domain/import/timetable_import.dart';
import 'package:nwu_schedule/features/import/presentation/timetable_import_page.dart';

void main() {
  final previousComparator = goldenFileComparator;
  late RemoteTimetable timetable;

  setUpAll(() {
    goldenFileComparator = _TolerantGoldenFileComparator(
      Uri.file(
        '${Directory.current.path}${Platform.pathSeparator}'
        'test${Platform.pathSeparator}'
        'golden${Platform.pathSeparator}'
        'timetable_import_preview_golden_test.dart',
      ),
      // This preview is text-dense. Linux and Windows system fonts differ by
      // about 1.34% of pixels while preserving layout, colors, and controls.
      // Keep the tolerance below a meaningful visual regression threshold.
      precisionTolerance: 0.015,
    );
    final fixture = jsonDecode(
      File('test/fixtures/zhengfang/timetable_response.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    timetable = const TimetableImportParser().parse(fixture);
  });

  tearDownAll(() => goldenFileComparator = previousComparator);

  for (final theme in officialThemes) {
    testWidgets(
      '${theme.id} real import preview golden',
      (tester) async {
        tester.view.physicalSize = const Size(480, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final diff = const ImportDiffEngine().build(
          incoming: timetable,
          local: null,
          previousImport: null,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: theme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: TimetableImportPreviewCard(
                  timetable: timetable,
                  diff: diff,
                  saving: false,
                  hasConflictItems: false,
                  onConfirm: () {},
                  onRetry: () {},
                  onCancel: () {},
                  onResolveConflicts: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(TimetableImportPreviewCard),
          matchesGoldenFile('goldens/import/${theme.id}.png'),
        );
      },
    );
  }
}

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  })  : assert(
          0 <= precisionTolerance && precisionTolerance <= 1,
          'precisionTolerance must be between 0 and 1',
        ),
        _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    final passed = result.passed || result.diffPercent <= _precisionTolerance;
    if (passed) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
