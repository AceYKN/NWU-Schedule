import 'package:flutter_test/flutter_test.dart';

import 'package:nwu_schedule/app/app.dart';

void main() {
  testWidgets('starts the NWU Schedule app', (WidgetTester tester) async {
    await tester.pumpWidget(const NwuScheduleRoot());
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('课表'), findsOneWidget);
    expect(find.text('日历'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
