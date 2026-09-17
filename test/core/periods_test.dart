import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/nwu/periods.dart';

void main() {
  test('keeps the NWU section schedule in one repository', () {
    const periods = NwuPeriodRepository();

    expect(periods.byNumber(1).label, '08:00 - 08:50');
    expect(periods.byNumber(3).label, '10:10 - 11:00');
    expect(periods.byNumber(11).label, '21:00 - 21:50');
  });
}
