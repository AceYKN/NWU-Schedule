import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
import '../../../app/theme/schedule_theme.dart';
import '../../../core/nwu/constants.dart';
import '../../../core/time/campus_clock.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/calendar/calendar_engine.dart';
import '../../../domain/errors/app_error.dart';
import '../../../domain/schedule/effective_course_instance.dart';
import '../../../domain/schedule/schedule_engine.dart';
import '../../../domain/semester/semester.dart';
import '../../shared/presentation/course_card.dart';
import '../application/home_schedule_status_resolver.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, this.now, this.clock});

  /// Optional fixed instant for deterministic UI tests. Production callers
  /// leave this null and use the device clock.
  final DateTime? now;

  /// Injectable live clock for testing countdowns and schedule transitions.
  final DateTime Function()? clock;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  Timer? _clockTimer;
  late final ValueNotifier<DateTime> _campusNow;
  HomeScheduleState? _displayedState;

  DateTime get _instant =>
      widget.now ?? widget.clock?.call() ?? DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _campusNow = ValueNotifier(CampusClock.toCampusWallTime(_instant));
    _startClock();
  }

  void _startClock() {
    _clockTimer?.cancel();
    if (widget.now == null) {
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _tick({bool forceRefresh = false}) {
    if (!mounted) return;
    final now = CampusClock.toCampusWallTime(_instant);
    final previous = _campusNow.value;
    final state = _displayedState;
    final crossedBoundary = switch (state) {
      HomeInClassState() => !now.isBefore(state.current.endTime),
      HomeBeforeNextClassState() => !now.isBefore(state.course.startTime),
      _ => false,
    };
    _campusNow.value = now;
    // Only countdown text ticks each second. Recompute the effective schedule
    // at minute/date changes, course boundaries, or after a clock correction.
    if (forceRefresh ||
        crossedBoundary ||
        now.isBefore(previous) ||
        !isSameDate(now, previous) ||
        now.hour != previous.hour ||
        now.minute != previous.minute) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.now != widget.now || oldWidget.clock != widget.clock) {
      _campusNow.value = CampusClock.toCampusWallTime(_instant);
      _startClock();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tick(forceRefresh: true);
      _startClock();
    } else {
      _clockTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _campusNow.dispose();
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
                    context.push('/import');
                  },
                  onLater: () => _completeOnboarding(ref),
                );
        }
        if (value is ScheduleCalendarMissing) {
          return _MissingCalendarContent(semester: value.semester);
        }
        final ready = value as ScheduleReady;
        final now = _instant;
        final state = const HomeScheduleStatusResolver().resolve(
          engine: ready.engine,
          now: now,
        );
        _displayedState = state;
        return _HomeContent(
          engine: ready.engine,
          state: state,
          clock: _campusNow,
          calendarUpdated: ready.calendarUpdated,
          onDismissCalendarUpdate: ready.calendarUpdated
              ? () => _dismissCalendarUpdate(ref, ready)
              : null,
          onRefresh: () async => _tick(forceRefresh: true),
        );
      },
    );
  }
}

class _NoSemesterContent extends StatelessWidget {
  const _NoSemesterContent();

  @override
  Widget build(BuildContext context) {
    final themeTokens = scheduleThemeTokensOf(context);
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
            SizedBox(height: themeTokens.sectionGap),
            FilledButton(
              onPressed: () => context.push('/import'),
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
                  '课表已成功读取',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  '当前版本尚未包含\n${semester.label}校历。\n\n'
                  '课程数据已安全保存，但当前版本缺少该学期校历，\n'
                  '因此暂时无法生成按日期计算的完整课表。更新到包含该校历的版本后即可正常使用。',
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
              nwuAppName,
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
    required this.clock,
    required this.calendarUpdated,
    required this.onDismissCalendarUpdate,
    required this.onRefresh,
  });

  final ScheduleEngine engine;
  final HomeScheduleState state;
  final ValueListenable<DateTime> clock;
  final bool calendarUpdated;
  final VoidCallback? onDismissCalendarUpdate;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final resolved = engine.resolveDate(state.now);
    final showTomorrow = state.now.hour >= 22;
    final agendaLabel = showTomorrow ? '明天' : '今天';
    final agendaDayLabel = showTomorrow ? '明日' : '今日';
    final agendaCourses = showTomorrow
        ? engine.getCoursesForDate(addCalendarDays(state.now, 1))
        : state.todayCourses;
    final themeTokens = scheduleThemeTokensOf(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          themeTokens.pagePadding,
          18,
          themeTokens.pagePadding,
          32,
        ),
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
          _HeroState(
            state: state,
            clock: clock,
            tomorrowCourses: showTomorrow ? agendaCourses : const [],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                agendaLabel,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Text(
                '${agendaCourses.length} 节',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (agendaCourses.isEmpty)
            _EmptyAgenda(dayLabel: agendaLabel)
          else
            ...agendaCourses.take(5).map(
                  (course) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CourseCard(
                      instance: course,
                      compact: true,
                      status: _agendaStatus(course, state),
                    ),
                  ),
                ),
          if (agendaCourses.length > 5)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showFullAgenda(
                  context,
                  agendaCourses,
                  dayLabel: agendaDayLabel,
                ),
                icon: const Icon(Icons.list_alt_outlined),
                label: Text('查看$agendaDayLabel全部课程（${agendaCourses.length}）'),
              ),
            ),
        ],
      ),
    );
  }

  String? _agendaStatus(
    EffectiveCourseInstance course,
    HomeScheduleState state,
  ) {
    if (state is HomeInClassState && state.current == course) {
      return '进行中';
    }
    if (state is HomeBeforeNextClassState && state.course == course) {
      return '下一节';
    }
    if (!course.endTime.isAfter(state.now)) {
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              week == null ? '当前不在校历教学周内' : '第 $week 教学周',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
  const _HeroState({
    required this.state,
    required this.clock,
    required this.tomorrowCourses,
  });

  final HomeScheduleState state;
  final ValueListenable<DateTime> clock;
  final List<EffectiveCourseInstance> tomorrowCourses;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (state is HomeInClassState) {
      final currentState = state as HomeInClassState;
      return _HeroCard(
        eyebrow: '正在上课',
        title: currentState.current.courseName,
        subtitle: _CourseCountdown(
          course: currentState.current,
          target: currentState.current.endTime,
          prefix: '距离下课',
          clock: clock,
          dayContext: _dayContext(currentState.todayType, currentState.now),
        ),
        background: scheme.primaryContainer,
        onTap: () => showCourseDetails(context, currentState.current),
      );
    }
    if (state is HomeBeforeNextClassState) {
      final nextState = state as HomeBeforeNextClassState;
      return _HeroCard(
        eyebrow: '下一节',
        title: nextState.course.courseName,
        subtitle: _CourseCountdown(
          course: nextState.course,
          target: nextState.course.startTime,
          prefix: '还有',
          clock: clock,
          dayContext: _dayContext(nextState.todayType, nextState.now),
        ),
        background: scheme.secondaryContainer,
        onTap: () => showCourseDetails(context, nextState.course),
      );
    }
    if (state.now.hour >= 22) {
      if (tomorrowCourses.isNotEmpty) {
        final course = tomorrowCourses.first;
        return _HeroCard(
          eyebrow: '明日安排',
          title: course.courseName,
          subtitle: Text(_activeCourseSubtitle(
            course,
            trailing: '明天第一节',
            dayContext: state.next == null
                ? null
                : _dayContext(state.next!.dayType, course.date),
          )),
          background: scheme.secondaryContainer,
          onTap: () => showCourseDetails(context, course),
        );
      }
      return _HeroCard(
        eyebrow: '明日安排',
        title: '明天暂无课程',
        subtitle: Text(_nextScheduleDescription(state.next)),
        background: scheme.surfaceContainerHighest,
        onTap: state.next == null
            ? null
            : () => showCourseDetails(context, state.next!.course),
      );
    }
    if (state is HomeTodayFinishedState) {
      final finishedState = state as HomeTodayFinishedState;
      return _HeroCard(
        eyebrow: '今日完成',
        title: '今天的课程已结束',
        subtitle: Text(_nextScheduleDescription(finishedState.next)),
        background: scheme.surfaceContainerHighest,
        onTap: finishedState.next == null
            ? null
            : () => showCourseDetails(context, finishedState.next!.course),
      );
    }
    if (state is HomeOutsideTeachingTermState) {
      return _HeroCard(
        eyebrow: '非教学期',
        title: '当前不在教学周',
        subtitle: Text(_nextScheduleDescription(state.next)),
        background: scheme.surfaceContainerHighest,
        onTap: state.next == null
            ? null
            : () => showCourseDetails(context, state.next!.course),
      );
    }
    final noClass = state as HomeNoClassTodayState;
    final holiday = noClass.todayType == AcademicDayType.holiday;
    return _HeroCard(
      eyebrow: holiday ? '休息日' : '今日安排',
      title: holiday ? '今天休息' : '今天暂无课程',
      subtitle: Text([
        if (_dayContext(noClass.todayType, noClass.now) case final context?)
          context,
        _nextScheduleDescription(noClass.next),
      ].join('\n')),
      background: scheme.surfaceContainerHighest,
      onTap: noClass.next == null
          ? null
          : () => showCourseDetails(context, noClass.next!.course),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.background,
    this.onTap,
  });

  final String eyebrow;
  final String title;
  final Widget subtitle;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final themeTokens = scheduleThemeTokensOf(context);
    return Card(
      key: const ValueKey('home-status-card'),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(themeTokens.todayCardRadius),
      ),
      color: background,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(themeTokens.todayCardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      letterSpacing: 0.2,
                      fontWeight: FontWeight.w600,
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
              subtitle,
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseCountdown extends StatelessWidget {
  const _CourseCountdown({
    required this.course,
    required this.target,
    required this.prefix,
    required this.clock,
    this.dayContext,
  });

  final EffectiveCourseInstance course;
  final DateTime target;
  final String prefix;
  final ValueListenable<DateTime> clock;
  final String? dayContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      if (course.location case final location?) location,
      if (course.teacher case final teacher?) teacher,
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_courseTimeRange(course), style: theme.textTheme.bodyMedium),
        if (details.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(details, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 12),
        ValueListenableBuilder<DateTime>(
          valueListenable: clock,
          builder: (context, now, child) => Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$prefix '),
                for (final part in RegExp(r'\d+|\D+')
                    .allMatches(_formatDuration(target.difference(now))))
                  TextSpan(
                    text: part.group(0),
                    style: int.tryParse(part.group(0)!) == null
                        ? null
                        : const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                  ),
              ],
            ),
            style: theme.textTheme.bodyMedium,
          ),
        ),
        if (dayContext != null) ...[
          const SizedBox(height: 6),
          Text(dayContext!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _EmptyAgenda extends StatelessWidget {
  const _EmptyAgenda({required this.dayLabel});

  final String dayLabel;

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
            Expanded(child: Text('$dayLabel没有排入课程的记录。')),
          ],
        ),
      ),
    );
  }
}

String _activeCourseSubtitle(
  EffectiveCourseInstance course, {
  required String trailing,
  String? dayContext,
}) {
  final details = [
    if (course.location case final location?) location,
    if (course.teacher case final teacher?) teacher,
  ].join(' · ');
  return [
    _courseTimeRange(course),
    if (details.isNotEmpty) details,
    trailing,
    if (dayContext != null) dayContext,
  ].join('\n');
}

String _nextScheduleDescription(NextScheduleSummary? next) {
  if (next == null) return '本学期暂无后续课程';
  final course = next.course;
  final time = _timeLabel(course.startTime);
  final when = switch (next.daysFromToday) {
    0 => '今天 $time',
    1 => '明天 $time',
    final days => '$days天后 · ${weekdayName(course.date.weekday)} $time',
  };
  return [
    '下一节',
    '$when · ${course.courseName}',
    if (course.location case final location?) location,
    if (_dayContext(next.dayType, course.date) case final context?) context,
  ].join('\n');
}

String? _dayContext(AcademicDayType type, DateTime date) {
  return switch (type) {
    AcademicDayType.normal => null,
    AcademicDayType.weekend => weekdayName(date.weekday),
    AcademicDayType.holiday => '校历：休假',
    AcademicDayType.makeupDay => '${weekdayName(date.weekday)} · 补课日',
  };
}

String _formatDuration(Duration duration) {
  // Round up fractional seconds so a future boundary never reads zero.
  final seconds =
      ((duration.inMicroseconds + 999999) ~/ 1000000).clamp(0, 86400);
  if (seconds < 60) return '$seconds 秒';
  final minutes = seconds ~/ 60;
  final remainderSeconds = seconds % 60;
  if (minutes < 60) return '$minutes 分钟 $remainderSeconds 秒';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return '$hours 小时 $remainder 分钟 $remainderSeconds 秒';
}

String _courseTimeRange(EffectiveCourseInstance course) {
  return '${_timeLabel(course.startTime)}–${_timeLabel(course.endTime)}';
}

String _timeLabel(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

void _showFullAgenda(
  BuildContext context,
  List<EffectiveCourseInstance> courses, {
  required String dayLabel,
}) {
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
                '$dayLabel全部课程',
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
