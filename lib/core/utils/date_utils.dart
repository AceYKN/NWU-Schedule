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
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw FormatException('Expected YYYY-MM-DD, got $value');
  }
  final parts = value.split('-').map(int.parse).toList();
  final date = DateTime(parts[0], parts[1], parts[2]);
  if (dateKey(date) != value) {
    throw FormatException('Invalid calendar date: $value');
  }
  return date;
}

String weekdayName(int weekday) {
  const names = ['一', '二', '三', '四', '五', '六', '日'];
  if (weekday < 1 || weekday > names.length) {
    throw RangeError('ISO weekday out of range: $weekday');
  }
  return '星期${names[weekday - 1]}';
}
