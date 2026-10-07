import 'course.dart';
import 'course_exception.dart';
import 'meeting_rule.dart';

/// Shared by transactional writes and backup validation.
String? exceptionReferenceError(
  CourseException exception, {
  required Map<String, Course> courses,
  required Map<String, MeetingRule> rules,
}) {
  final course = courses[exception.courseId];
  if (exception.courseId != null && course == null) {
    return '临时变更 ${exception.id} 引用了不存在的课程';
  }
  if (course != null && course.semesterId != exception.semesterId) {
    return '临时变更 ${exception.id} 的课程与学期不一致';
  }
  if (exception.type != CourseExceptionType.add ||
      exception.sourceMeetingId != null) {
    final rule = rules[exception.sourceMeetingId];
    if (rule == null) {
      return '临时变更 ${exception.id} 引用了不存在的上课安排';
    }
    if (rule.courseId != exception.courseId) {
      return '临时变更 ${exception.id} 的上课安排与课程不一致';
    }
  }
  return null;
}
