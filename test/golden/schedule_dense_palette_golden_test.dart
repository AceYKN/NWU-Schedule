import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/app/theme/schedule_theme.dart';
import 'package:nwu_schedule/domain/settings/schedule_display_preferences.dart';
import 'package:nwu_schedule/features/schedule/presentation/widgets/schedule_week_grid.dart';
import 'package:nwu_schedule/features/shared/presentation/course_color_resolver.dart';

import '../helpers/schedule_palette_fixture.dart';

import '../support/schedule_golden_comparator.dart';

void main() {
  final previousComparator = goldenFileComparator;

  setUpAll(() {
    // Card colors are also checked without tolerance in schedule_palette_test.
    goldenFileComparator = ScheduleGoldenComparator(
      Uri.file(
        '${Directory.current.path}${Platform.pathSeparator}'
        'test${Platform.pathSeparator}golden${Platform.pathSeparator}'
        'schedule_dense_palette_golden_test.dart',
      ),
      precisionTolerance: .015,
    );
  });

  tearDownAll(() => goldenFileComparator = previousComparator);

  for (final theme in officialThemes) {
    for (final brightness in Brightness.values) {
      testWidgets('${theme.id} ${brightness.name} dense week palette',
          (tester) async {
        tester.view.physicalSize = const Size(430, 816);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final model = paletteWeekModel();
        final palette = CourseColorResolver.schedulePaletteForCourses(
          model.entries.map((entry) => entry.course),
        );
        await tester.pumpWidget(MaterialApp(
          theme: brightness == Brightness.light ? theme.light() : theme.dark(),
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('dense-week-grid'),
              child: ScheduleWeekGrid(
                visibleDays: model.days,
                viewModel: model,
                coursePalette: palette,
                preferences: const ScheduleDisplayPreferences.defaults(),
                now: DateTime(2026, 9, 7, 8, 20),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const ValueKey('dense-week-grid')),
          matchesGoldenFile(
            'goldens/actual/pages/dense_week_${theme.id}_${brightness.name}.png',
          ),
        );
      });
    }
  }
}
