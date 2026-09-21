import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/domain/course/week_pattern.dart';
import 'package:nwu_schedule/features/schedule/presentation/course_form_fields.dart';

void main() {
  testWidgets('teaching week presets and chips produce explicit selections',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _WeekSelectorHarness()));

    expect(find.text('本安排覆盖 16 周'), findsOneWidget);
    await tester.tap(find.text('单周'));
    await tester.pump();
    expect(find.text('本安排覆盖 8 周'), findsOneWidget);
    expect(find.text('自定义'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('第 1 周，已选择'));
    await tester.pump();
    expect(find.text('本安排覆盖 7 周'), findsOneWidget);
    expect(find.byWidgetPredicate((widget) {
      return widget is ChoiceChip &&
          widget.selected &&
          (widget.label as Text).data == '自定义';
    }), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('第 1 周，未选择'));
    await tester.pump();
    expect(find.text('本安排覆盖 8 周'), findsOneWidget);
  });

  testWidgets('cannot deselect the final teaching week', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: _WeekSelectorHarness(
          startWeek: 1,
          endWeek: 1,
          mode: WeekSelectionMode.custom,
          selectedWeeks: {1},
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('第 1 周，已选择'));
    await tester.pump();
    expect(find.text('至少选择一个教学周'), findsOneWidget);
    expect(find.text('本安排覆盖 1 周'), findsOneWidget);
  });

  testWidgets('notes keep a compact multiline contract', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompactNotesField(controller: controller),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.minLines, 2);
    expect(field.maxLines, 3);
  });

  testWidgets('section range changes clamp the other endpoint', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _SectionHarness()));

    var fields = find.byType(DropdownButtonFormField<int>);
    tester.widget<DropdownButtonFormField<int>>(fields.at(0)).onChanged!(8);
    await tester.pump();
    expect(find.text('8-8'), findsOneWidget);

    fields = find.byType(DropdownButtonFormField<int>);
    tester.widget<DropdownButtonFormField<int>>(fields.at(1)).onChanged!(3);
    await tester.pump();
    expect(find.text('8-8'), findsOneWidget);
  });
}

class _WeekSelectorHarness extends StatefulWidget {
  const _WeekSelectorHarness({
    this.startWeek = 1,
    this.endWeek = 16,
    this.mode = WeekSelectionMode.all,
    this.selectedWeeks,
  });

  final int startWeek;
  final int endWeek;
  final WeekSelectionMode mode;
  final Set<int>? selectedWeeks;

  @override
  State<_WeekSelectorHarness> createState() => _WeekSelectorHarnessState();
}

class _WeekSelectorHarnessState extends State<_WeekSelectorHarness> {
  late int _startWeek;
  late int _endWeek;
  late WeekSelectionMode _mode;
  late Set<int> _selectedWeeks;

  @override
  void initState() {
    super.initState();
    _startWeek = widget.startWeek;
    _endWeek = widget.endWeek;
    _mode = widget.mode;
    _selectedWeeks = widget.selectedWeeks ??
        {
          for (var week = widget.startWeek; week <= widget.endWeek; week++)
            week,
        };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: TeachingWeekSelector(
          totalWeeks: 16,
          startWeek: _startWeek,
          endWeek: _endWeek,
          mode: _mode,
          selectedWeeks: _selectedWeeks,
          onChanged: (selection) => setState(() {
            _startWeek = selection.startWeek;
            _endWeek = selection.endWeek;
            _mode = selection.mode;
            _selectedWeeks = selection.selectedWeeks.toSet();
          }),
        ),
      ),
    );
  }
}

class _SectionHarness extends StatefulWidget {
  const _SectionHarness();

  @override
  State<_SectionHarness> createState() => _SectionHarnessState();
}

class _SectionHarnessState extends State<_SectionHarness> {
  int _start = 5;
  int _end = 7;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('$_start-$_end'),
          SectionRangeSelector(
            startSection: _start,
            endSection: _end,
            onChanged: (selection) => setState(() {
              _start = selection.start;
              _end = selection.end;
            }),
          ),
        ],
      ),
    );
  }
}
