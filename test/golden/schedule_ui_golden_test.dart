import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/app/theme/schedule_theme.dart';
import 'package:nwu_schedule/core/utils/week_mask.dart';
import 'package:nwu_schedule/domain/course/course.dart';
import 'package:nwu_schedule/domain/course/meeting_rule.dart';
import 'package:nwu_schedule/domain/schedule/effective_course_instance.dart';
import 'package:nwu_schedule/features/shared/presentation/course_card.dart';

void main() {
  for (final theme in officialThemes) {
    testWidgets(
      '${theme.id} schedule UI golden',
      (tester) async {
        tester.view.physicalSize = const Size(420, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: theme.light(),
            home: Scaffold(
              body: _GoldenScheduleBoard(instance: _fixtureInstance()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byKey(const ValueKey('schedule-golden-board')),
          matchesGoldenFile('goldens/schedule/${theme.id}.png'),
        );
      },
    );
  }
}

EffectiveCourseInstance _fixtureInstance() {
  final course = Course(
    id: 'golden-course',
    semesterId: 'golden-semester',
    sourceType: CourseSourceType.manual,
    name: '软件测试',
    code: 'CS301',
    note: 'Golden fixture',
    colorOverride: 0xff526579,
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );
  final rule = MeetingRule(
    id: 'golden-rule',
    courseId: course.id,
    weekday: DateTime.monday,
    startSection: 3,
    endSection: 4,
    teacher: '苏峙之',
    campus: '长安校区',
    room: '3406',
    weekMask: WeekMask.all(20),
  );
  return EffectiveCourseInstance(
    course: course,
    meetingRule: rule,
    date: DateTime(2026, 9, 14),
    templateDate: DateTime(2026, 9, 14),
    startSection: 3,
    endSection: 4,
    startTime: DateTime(2026, 9, 14, 10, 10),
    endTime: DateTime(2026, 9, 14, 12),
    teacher: rule.teacher,
    campus: rule.campus,
    room: rule.room,
  );
}

class _GoldenScheduleBoard extends StatelessWidget {
  const _GoldenScheduleBoard({required this.instance});

  final EffectiveCourseInstance instance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      key: const ValueKey('schedule-golden-board'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _StateCard(
            label: 'NOW',
            title: '软件测试',
            detail: '10:10–12:00 · 3406',
            color: scheme.primaryContainer,
          ),
          _StateCard(
            label: 'NEXT',
            title: '人工智能',
            detail: '14:00–14:50 · 1310',
            color: scheme.secondaryContainer,
          ),
          _StateCard(
            label: 'TODAY DONE',
            title: '今天的课程已经结束',
            detail: '下一节：明天 08:00 数据结构实验',
            color: scheme.surfaceContainerHighest,
          ),
          _StateCard(
            label: 'NO CLASS',
            title: '今天没有课程',
            detail: '下一节：周一 08:00 数据结构实验',
            color: scheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 14),
          Text(
            'Course Card',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          CourseCard(instance: instance, status: 'NEXT'),
          const SizedBox(height: 14),
          Text(
            'Week · Month',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _WeekPreview(instance: instance),
          const SizedBox(height: 10),
          _MonthPreview(),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.merge_type),
              title: const Text('课表发生变化'),
              subtitle: const Text('新增 1 · 更新 2 · 删除 1 · 冲突 0'),
              trailing: FilledButton.tonal(
                onPressed: () {},
                child: const Text('确认'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.label,
    required this.title,
    required this.detail,
    required this.color,
  });

  final String label;
  final String title;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = scheduleThemeTokensOf(context);
    return Card(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.todayCardRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.todayCardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(detail),
          ],
        ),
      ),
    );
  }
}

class _WeekPreview extends StatelessWidget {
  const _WeekPreview({required this.instance});

  final EffectiveCourseInstance instance;

  @override
  Widget build(BuildContext context) {
    final tokens = scheduleThemeTokensOf(context);
    return Card(
      child: Table(
        border: TableBorder.all(
          color: Theme.of(context).dividerColor,
          width: tokens.gridBorderWidth,
        ),
        defaultColumnWidth: const FlexColumnWidth(),
        children: [
          const TableRow(
            children: [
              _GridText('节次'),
              _GridText('一'),
              _GridText('二'),
              _GridText('三'),
              _GridText('四'),
              _GridText('五'),
            ],
          ),
          TableRow(
            children: [
              const _GridText('3\n10:10'),
              _GridText(instance.courseName),
              const _GridText(''),
              const _GridText(''),
              const _GridText(''),
              const _GridText(''),
            ],
          ),
        ],
      ),
    );
  }
}

class _GridText extends StatelessWidget {
  const _GridText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Center(
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}

class _MonthPreview extends StatelessWidget {
  const _MonthPreview();

  @override
  Widget build(BuildContext context) {
    final tokens = scheduleThemeTokensOf(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(tokens.monthCellPadding),
        child: GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (final day in ['一', '二', '三', '四', '五', '六', '日'])
              Center(
                child: Text(
                  day,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            for (var day = 1; day <= 14; day++)
              Container(
                height: tokens.monthCellHeight,
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.all(4),
                color: day == 8
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: Text('$day'),
              ),
          ],
        ),
      ),
    );
  }
}
