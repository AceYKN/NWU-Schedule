import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/app/theme/schedule_theme.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/features/shared/presentation/course_color_resolver.dart';

void main() {
  testWidgets('course palette across official themes', (tester) async {
    tester.view.physicalSize = const Size(720, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final course = Course(
      id: 'palette-preview',
      semesterId: 'palette-preview',
      sourceType: CourseSourceType.manual,
      name: '预览课程',
    );
    final schemes = [
      for (final theme in officialThemes) ...[
        theme.light().colorScheme,
        theme.dark().colorScheme,
      ],
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: const ValueKey('course-palette'),
          child: Column(
            children: [
              for (final scheme in schemes)
                SizedBox(
                  height: 80,
                  child: ColoredBox(
                    color: scheme.surface,
                    child: Row(
                      children: [
                        for (var index = 0;
                            index < CourseColorResolver.schedulePaletteLength();
                            index++)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 10,
                            ),
                            child: ColoredBox(
                              color: CourseColorResolver.resolveSchedule(
                                course,
                                scheme,
                                paletteIndex: index,
                              ).container,
                              child: const SizedBox(width: 24, height: 60),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    await expectLater(
      find.byKey(const ValueKey('course-palette')),
      matchesGoldenFile('goldens/actual/pages/course_palette_all_themes.png'),
    );
  });
}
