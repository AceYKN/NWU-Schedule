/// Domain-level clock helpers for the NWU campus timezone.
///
/// Date-only values in the domain are wall-clock values in Asia/Shanghai. An
/// instant passed to [toCampusWallTime] is converted through UTC and then
/// represented as a local-looking wall-clock value. This keeps the domain
/// independent from Android/iOS timezone APIs.
class CampusClock {
  const CampusClock._();

  static const offset = Duration(hours: 8);

  static DateTime now() {
    return toCampusWallTime(DateTime.now().toUtc());
  }

  static DateTime toCampusWallTime(DateTime instant) {
    final campus = instant.toUtc().add(offset);
    return DateTime(
      campus.year,
      campus.month,
      campus.day,
      campus.hour,
      campus.minute,
      campus.second,
      campus.millisecond,
      campus.microsecond,
    );
  }
}
