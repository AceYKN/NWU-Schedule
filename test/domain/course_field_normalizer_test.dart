import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/domain/course/course_field_normalizer.dart';

void main() {
  test('removes repeated field labels with either colon style', () {
    expect(normalizeTeacherField('教师：  杨建锋'), '杨建锋');
    expect(normalizeTeacherField('教师:教师：杨建锋'), '杨建锋');
    expect(normalizeCampusField('校区: 长安校区'), '长安校区');
    expect(normalizeCampusField('校区名称：长安校区'), '长安校区');
    expect(normalizeRoomField('上课地点：1405'), '1405');
    expect(normalizeRoomField('教室: 1405'), '1405');
  });

  test('keeps legitimate values and normalizes optional blanks', () {
    expect(normalizeTeacherField('杨建锋'), '杨建锋');
    expect(normalizeCampusField('长安校区'), '长安校区');
    expect(normalizeRoomField('计算机技术实验室-321'), '计算机技术实验室-321');
    expect(normalizeOptionalCourseField('   '), isNull);
  });

  test('normalization is idempotent', () {
    const raw = '教师：教师：杨建锋';
    final once = normalizeTeacherField(raw);
    expect(normalizeTeacherField(once), once);
  });
}
