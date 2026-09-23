import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/domain/course/course_identity.dart';

void main() {
  group('CourseIdentity', () {
    test('normalizes whitespace, non-breaking spaces, and case', () {
      expect(
        CourseIdentity.nameKey('  SOFTWARE\u00a0  Testing  '),
        'software testing',
      );
      expect(CourseIdentity.sameName('软件测试\u00a0', ' 软件测试 '), isTrue);
    });

    test('keeps punctuation and suffixes as identity', () {
      expect(CourseIdentity.sameName('软件测试', '软件测试（双语）'), isFalse);
      expect(CourseIdentity.sameName('C++', 'C#'), isFalse);
    });

    test('creates a stable term and normalized-name import key', () {
      expect(
        CourseIdentity.importSourceKey('2026-2027-1', '机器学习'),
        CourseIdentity.importSourceKey('2026-2027-1', ' 机器学习\u00a0'),
      );
      expect(
        CourseIdentity.importSourceKey('2026-2027-1', '机器学习'),
        isNot(CourseIdentity.importSourceKey('2026-2027-2', '机器学习')),
      );
    });
  });
}
