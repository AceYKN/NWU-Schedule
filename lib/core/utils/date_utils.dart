DateTime dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

bool isSameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String dateKey(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

DateTime parseDateOnly(String value) {
  final parts = value.split('-');
  if (parts.length != 3) {
    throw FormatException('Expected YYYY-MM-DD, got $value');
  }
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

String weekdayName(int weekday) {
  const names = ['一', '二', '三', '四', '五', '六', '日'];
  if (weekday < 1 || weekday > names.length) {
    throw RangeError('ISO weekday out of range: $weekday');
  }
  return '星期${names[weekday - 1]}';
}
