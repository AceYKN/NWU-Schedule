import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/domain/course/course_exception.dart';

void main() {
  test('exception overrides only persist changed effective values', () {
    expect(exceptionOverrideIfChanged(' 苏临之 ', '苏临之'), isNull);
    expect(exceptionOverrideIfChanged('', null), isNull);
    expect(exceptionOverrideIfChanged('李老师', '苏临之'), '李老师');
    expect(exceptionOverrideIfChanged('', '苏临之'), '');
  });
}
