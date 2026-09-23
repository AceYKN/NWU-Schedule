import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/features/schedule/presentation/widgets/course_block_density.dart';

void main() {
  group('resolveCourseBlockDensity', () {
    test('uses dense layout for narrow columns and seven visible days', () {
      expect(
        resolveCourseBlockDensity(width: 55.9, height: 100, visibleDayCount: 5),
        CourseBlockDensity.dense,
      );
      expect(
        resolveCourseBlockDensity(width: 100, height: 100, visibleDayCount: 7),
        CourseBlockDensity.dense,
      );
    });

    test('uses compact layout below roomy width or height thresholds', () {
      expect(
        resolveCourseBlockDensity(width: 71.9, height: 100, visibleDayCount: 5),
        CourseBlockDensity.compact,
      );
      expect(
        resolveCourseBlockDensity(width: 72, height: 69.9, visibleDayCount: 5),
        CourseBlockDensity.compact,
      );
    });

    test('uses roomy layout at the inclusive width and height thresholds', () {
      expect(
        resolveCourseBlockDensity(width: 72, height: 70, visibleDayCount: 5),
        CourseBlockDensity.roomy,
      );
    });
  });
}
