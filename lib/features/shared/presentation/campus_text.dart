import 'package:flutter/material.dart';

import '../../../app/l10n/campus_strings.dart';
import '../../../app/theme/campus_design.dart';
import '../../../core/utils/date_utils.dart' as dates;
import '../../../core/utils/week_mask.dart';
import '../../../domain/errors/app_error.dart';

/// Translate interface templates before inserting course or other user data.
String campusText(
  BuildContext context,
  String source, {
  Map<String, Object?> values = const {},
}) {
  final template = CampusDesign.maybeOf(context) == null
      ? source
      : CampusStrings.lookup(source);
  return template.replaceAllMapped(RegExp(r'\{(\d+)\}'), (match) {
    final key = match.group(1)!;
    return values.containsKey(key) ? '${values[key]}' : match.group(0)!;
  });
}

String campusWeekdayName(BuildContext context, int weekday) =>
    CampusDesign.maybeOf(context) == null
        ? dates.weekdayName(weekday)
        : CampusDesign.weekdayName(weekday);

String campusWeekMask(BuildContext context, WeekMask mask) {
  return campusWeekText(context, formatWeekMask(mask));
}

/// Only for week summaries produced by the schedule UI, never user notes.
String campusWeekText(BuildContext context, String source) {
  if (CampusDesign.maybeOf(context) == null) return source;
  return source
      .replaceAll('无教学周', '授業週なし')
      .replaceAll('单周', '奇数週')
      .replaceAll('双周', '偶数週')
      .replaceAll('周', '週');
}

String campusUserMessage(BuildContext context, Object error, {String? action}) {
  final message = campusText(context, classifyNwuError(error).userMessage);
  return action == null ? message : '$action：$message';
}
