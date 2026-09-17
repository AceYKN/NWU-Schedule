import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/calendar/calendar_engine.dart';
import '../../../domain/schedule/effective_course_instance.dart';
import '../../../domain/schedule/schedule_engine.dart';
import '../../../domain/schedule/schedule_now_state.dart';
import '../../shared/presentation/course_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

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
      error: (error, stackTrace) => const Center(
        child: Text('暂时无法读取本地课表'),
      ),
      data: (value) {
        if (value is ScheduleNoSemester) {
          return const _NoSemesterContent();
        }
        if (value is ScheduleCalendarMissing) {
          return Center(
            child: Text('${value.semester.label}的校历尚未包含在当前版本中'),
          );
        }
        final ready = value as ScheduleReady;
        return _HomeContent(
          engine: ready.engine,
          state: ready.engine.getStateAt(DateTime.now().toUtc()),
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

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.engine,
    required this.state,
    required this.onRefresh,
  });

  final ScheduleEngine engine;
  final ScheduleNowState state;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final resolved = engine.calendarEngine.resolve(state.now);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          _HomeHeader(resolved: resolved),
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
            ...state.todayCourses.map(
              (course) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CourseCard(
                  instance: course,
                  compact: true,
                  status: _agendaStatus(course, state),
                ),
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
    return Card(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(20),
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
  return '${weekdayName(course.date.weekday)} ${course.startTime.hour.toString().padLeft(2, '0')}:${course.startTime.minute.toString().padLeft(2, '0')} ${course.courseName} · ${course.location ?? '地点待补充'}';
}
