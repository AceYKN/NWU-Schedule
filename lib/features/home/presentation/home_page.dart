import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
import '../../../app/theme/schedule_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/calendar/calendar_engine.dart';
import '../../../domain/errors/app_error.dart';
import '../../../domain/schedule/effective_course_instance.dart';
import '../../../domain/schedule/schedule_engine.dart';
import '../../../domain/schedule/schedule_now_state.dart';
import '../../../domain/semester/semester.dart';
import '../../shared/presentation/course_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, this.now});

  /// Optional fixed instant for deterministic UI tests. Production callers
  /// leave this null and use the device clock.
  final DateTime? now;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final load = ref.watch(scheduleLoadProvider);
    return load.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(nwuUserMessage(error, action: '读取本地课表失败')),
      ),
      data: (value) {
        if (value is ScheduleNoSemester) {
          final completed =
              ref.watch(onboardingCompletedProvider).asData?.value ?? false;
          return completed
              ? const _NoSemesterContent()
              : _WelcomeContent(
                  onImport: () {
                    unawaited(_completeOnboarding(ref));
                    context.go('/import');
                  },
                  onLater: () => _completeOnboarding(ref),
                );
        }
        if (value is ScheduleCalendarMissing) {
          return _MissingCalendarContent(semester: value.semester);
        }
        final ready = value as ScheduleReady;
        final now = widget.now ?? DateTime.now().toUtc();
        return _HomeContent(
          engine: ready.engine,
          state: ready.engine.getStateAt(now),
          calendarUpdated: ready.calendarUpdated,
          onDismissCalendarUpdate: ready.calendarUpdated
              ? () => _dismissCalendarUpdate(ref, ready)
              : null,
          onRefresh: () async => setState(() {}),
        );
      },
    );
  }
}

class _NoSemesterContent extends StatelessWidget {
  const _NoSemesterContent();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('还没有课表', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            const Text('从西北大学教务系统导入后，\n这里会自动结合校历显示课程。',
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go('/import'),
              child: const Text('导入课表'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingCalendarContent extends StatelessWidget {
  const _MissingCalendarContent({required this.semester});

  final Semester semester;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '课表已保存',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  '当前版本尚未包含\n${semester.label}校历。\n\n'
                  '课程数据已经保存；在校历更新前，教学周、放假和调休信息可能无法完全准确计算。',
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: () => context.go('/settings'),
                    child: const Text('查看设置'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent({required this.onImport, required this.onLater});

  final VoidCallback onImport;
  final Future<void> Function() onLater;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('欢迎', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '西北大学课程表',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            const Text('无广告\n本地存储\n结合学校校历'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onImport,
                child: const Text('导入我的课表'),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => onLater(),
                child: const Text('稍后再说'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _completeOnboarding(WidgetRef ref) async {
  await ref
      .read(scheduleDataRepositoryProvider)
      .setSetting('onboarding.completed', 'true');
  ref.invalidate(onboardingCompletedProvider);
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.engine,
    required this.state,
    required this.calendarUpdated,
    required this.onDismissCalendarUpdate,
    required this.onRefresh,
  });

  final ScheduleEngine engine;
  final ScheduleNowState state;
  final bool calendarUpdated;
  final VoidCallback? onDismissCalendarUpdate;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final resolved = engine.resolveDate(state.now);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          _HomeHeader(resolved: resolved),
          if (calendarUpdated) ...[
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                leading: const Icon(Icons.update_outlined),
                title: const Text('西北大学校历已更新'),
                subtitle: const Text('课表、上课提醒和桌面 Widget 已按新校历重新计算。'),
                trailing: IconButton(
                  tooltip: '关闭提示',
                  onPressed: onDismissCalendarUpdate,
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          _HeroState(state: state),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                '今天',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Text(
                '${state.todayCourses.length} 节',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (state.todayCourses.isEmpty)
            const _EmptyAgenda()
          else
            ...state.todayCourses.take(5).map(
                  (course) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CourseCard(
                      instance: course,
                      compact: true,
                      status: _agendaStatus(course, state),
                    ),
                  ),
                ),
          if (state.todayCourses.length > 5)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showFullAgenda(context, state.todayCourses),
                icon: const Icon(Icons.list_alt_outlined),
                label: Text('查看今日全部课程（${state.todayCourses.length}）'),
              ),
            ),
        ],
      ),
    );
  }

  String? _agendaStatus(
    EffectiveCourseInstance course,
    ScheduleNowState state,
  ) {
    if (state is ScheduleCurrent && state.current == course) {
      return 'NOW';
    }
    if (state is ScheduleNext && state.next == course) {
      return 'NEXT';
    }
    if (course.endTime.isBefore(state.now)) {
      return '已结束';
    }
    return null;
  }
}

Future<void> _dismissCalendarUpdate(
  WidgetRef ref,
  ScheduleReady ready,
) async {
  await ref.read(scheduleDataRepositoryProvider).saveSemester(
        ready.semester.copyWith(
          calendarRevision: ready.engine.calendarRevision,
        ),
      );
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.resolved});

  final ResolvedCalendarDate resolved;

  @override
  Widget build(BuildContext context) {
    final date = resolved.actualDate;
    final week = resolved.teachingWeek;
    final label = resolved.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${date.year}年${date.month}月${date.day}日 ${weekdayName(date.weekday)}',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              week == null ? '当前不在校历教学周内' : '第 $week 教学周',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (label != null && label.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(label),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _HeroState extends StatelessWidget {
  const _HeroState({required this.state});

  final ScheduleNowState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (state is ScheduleCurrent) {
      final currentState = state as ScheduleCurrent;
      return _HeroCard(
        eyebrow: 'NOW',
        title: currentState.current.courseName,
        subtitle: _courseSubtitle(currentState.current),
        background: scheme.primaryContainer,
      );
    }
    if (state is ScheduleNext) {
      final nextState = state as ScheduleNext;
      return _HeroCard(
        eyebrow: 'NEXT',
        title: nextState.next.courseName,
        subtitle: _courseSubtitle(nextState.next),
        background: scheme.secondaryContainer,
      );
    }
    if (state is ScheduleFinishedToday) {
      final finishedState = state as ScheduleFinishedToday;
      return _HeroCard(
        eyebrow: 'TODAY DONE',
        title: '今天的课程已经结束',
        subtitle: finishedState.next == null
            ? '当前学期没有更多课程'
            : '下一节：${_nextDescription(finishedState.next!)}',
        background: scheme.surfaceContainerHighest,
      );
    }
    final noClass = state as ScheduleNoClassToday;
    return _HeroCard(
      eyebrow: 'NO CLASS',
      title: '今天没有课程',
      subtitle: noClass.next == null
          ? '当前学期没有待上课程'
          : '下一节：${_nextDescription(noClass.next!)}',
      background: scheme.surfaceContainerHighest,
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.background,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final themeTokens = scheduleThemeTokensOf(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(themeTokens.todayCardRadius),
      ),
      color: background,
      child: Padding(
        padding: EdgeInsets.all(themeTokens.todayCardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(subtitle),
          ],
        ),
      ),
    );
  }
}

class _EmptyAgenda extends StatelessWidget {
  const _EmptyAgenda();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('今天没有排入课程的记录。')),
          ],
        ),
      ),
    );
  }
}

String _courseSubtitle(EffectiveCourseInstance course) {
  final time =
      '${course.startTime.hour.toString().padLeft(2, '0')}:${course.startTime.minute.toString().padLeft(2, '0')}'
      '–${course.endTime.hour.toString().padLeft(2, '0')}:${course.endTime.minute.toString().padLeft(2, '0')}';
  return '$time\n${course.location ?? '地点待补充'}${course.teacher == null ? '' : ' · ${course.teacher}'}';
}

String _nextDescription(EffectiveCourseInstance course) {
  final teacher = course.teacher == null ? '' : ' · ${course.teacher}';
  return '${weekdayName(course.date.weekday)} ${course.startTime.hour.toString().padLeft(2, '0')}:${course.startTime.minute.toString().padLeft(2, '0')} ${course.courseName} · ${course.location ?? '地点待补充'}$teacher';
}

void _showFullAgenda(
  BuildContext context,
  List<EffectiveCourseInstance> courses,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
          ),
          child: ListView(
            children: [
              Text(
                '今日全部课程',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 14),
              for (final course in courses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CourseCard(instance: course),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
