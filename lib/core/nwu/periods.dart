/// 西北大学本科生教学节次。
///
/// 1-10 节来自西北大学公开的学生作息时间表；第 11 节按 SPEC 暂存，
/// 正式发布前必须再和学校最新作息核验。业务层只依赖本仓库，UI 不应
/// 直接写入任何课程时间；学校调整作息时只修改这里。
class NwuPeriod {
  const NwuPeriod({
    required this.number,
    required this.startMinutes,
    required this.endMinutes,
  });

  final int number;
  final int startMinutes;
  final int endMinutes;

  DateTime startAt(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      startMinutes ~/ 60,
      startMinutes % 60,
    );
  }

  DateTime endAt(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      endMinutes ~/ 60,
      endMinutes % 60,
    );
  }

  String get startLabel => formatMinutes(startMinutes);

  String get endLabel => formatMinutes(endMinutes);

  String get label => '$startLabel - $endLabel';
}

class NwuPeriodRepository {
  const NwuPeriodRepository();

  static const all = <NwuPeriod>[
    NwuPeriod(number: 1, startMinutes: 8 * 60, endMinutes: 8 * 60 + 50),
    NwuPeriod(number: 2, startMinutes: 9 * 60, endMinutes: 9 * 60 + 50),
    NwuPeriod(number: 3, startMinutes: 10 * 60 + 10, endMinutes: 11 * 60),
    NwuPeriod(number: 4, startMinutes: 11 * 60 + 10, endMinutes: 12 * 60),
    NwuPeriod(number: 5, startMinutes: 14 * 60, endMinutes: 14 * 60 + 50),
    NwuPeriod(number: 6, startMinutes: 15 * 60, endMinutes: 15 * 60 + 50),
    NwuPeriod(number: 7, startMinutes: 16 * 60, endMinutes: 16 * 60 + 50),
    NwuPeriod(number: 8, startMinutes: 17 * 60, endMinutes: 17 * 60 + 50),
    NwuPeriod(number: 9, startMinutes: 19 * 60, endMinutes: 19 * 60 + 50),
    NwuPeriod(number: 10, startMinutes: 20 * 60, endMinutes: 20 * 60 + 50),
    NwuPeriod(number: 11, startMinutes: 21 * 60, endMinutes: 21 * 60 + 50),
  ];

  NwuPeriod byNumber(int number) {
    return all.firstWhere(
      (period) => period.number == number,
      orElse: () => throw RangeError('Unknown NWU period: $number'),
    );
  }
}

String formatMinutes(int minutes) {
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}
