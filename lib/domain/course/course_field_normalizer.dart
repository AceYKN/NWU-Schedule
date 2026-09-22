String? normalizeOptionalCourseField(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String? normalizeTeacherField(String? value) => _normalizeLabeledField(
      value,
      const ['教师', '任课教师', '上课教师'],
    );

String? normalizeCampusField(String? value) => _normalizeLabeledField(
      value,
      const ['校区', '校区名称'],
    );

String? normalizeRoomField(String? value) => _normalizeLabeledField(
      value,
      const ['上课地点', '教室', '地点'],
    );

String? _normalizeLabeledField(String? value, List<String> labels) {
  var normalized = normalizeOptionalCourseField(value);
  if (normalized == null) return null;
  final prefix = RegExp(
    '^(?:${labels.map(RegExp.escape).join('|')})\\s*[:：]\\s*',
  );
  while (prefix.hasMatch(normalized!)) {
    normalized = normalizeOptionalCourseField(
      normalized.replaceFirst(prefix, ''),
    );
    if (normalized == null) return null;
  }
  return normalized;
}
