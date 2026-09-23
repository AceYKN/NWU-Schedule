import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
import '../../../core/time/campus_clock.dart';
import '../../../domain/calendar/calendar_definition.dart';
import '../../../domain/errors/app_error.dart';
import '../../../domain/schedule/effective_course_instance.dart';
import '../../../domain/schedule/schedule_engine.dart';
import '../../../domain/settings/schedule_display_preferences.dart';
import '../../../domain/schedule/week_schedule_view_model.dart';
import 'widgets/schedule_week_grid.dart';
import 'widgets/schedule_week_display_filter.dart';
import 'widgets/schedule_quick_detail_sheet.dart';
import 'widgets/timeslot_semester_schedule.dart';
import '../../shared/presentation/course_card.dart';

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key, this.now});

  /// Optional fixed instant for deterministic UI tests. Production callers
  /// leave this null and use the device clock.
  final DateTime? now;

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  int? selectedWeek;
  bool temporaryWeekendExpanded = false;
  Timer? _clockTimer;
  DateTime? _liveNow;
  ScheduleEngine? _timeslotCacheEngine;
  final Map<(int, int, int), TimeslotSemesterSchedule> _timeslotCache = {};

  @override
  void initState() {
    super.initState();
    if (widget.now == null) {
      _liveNow = DateTime.now().toUtc();
      _scheduleNextClockTick();
    }
  }

  @override
  void didUpdateWidget(covariant SchedulePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.now == widget.now) return;
    _clockTimer?.cancel();
    _liveNow = widget.now == null ? DateTime.now().toUtc() : null;
    if (widget.now == null) _scheduleNextClockTick();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final load = ref.watch(scheduleLoadProvider);
    return load.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text(nwuUserMessage(error, action: '读取本地课表失败'))),
      data: (value) {
        if (value is ScheduleNoSemester) {
          return _ScheduleEmptyState(
            onImport: () => context.go('/import'),
            onManual: () => context.go('/course/new'),
          );
        }
        if (value is ScheduleCalendarMissing) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '${value.semester.label}暂无可用校历，请先更新校历数据。',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (value is! ScheduleReady) {
          return const Center(child: Text('当前没有可展示的课表'));
        }

        final engine = value.engine;
        final now = widget.now ?? _liveNow ?? DateTime.now().toUtc();
        final preferences =
            ref.watch(scheduleDisplayPreferencesProvider).asData?.value ??
                const ScheduleDisplayPreferences.defaults();
        final currentWeek = engine.teachingWeekAt(now) ?? 1;
        final maxWeek = engine.totalWeeks;
        final week = (selectedWeek ?? currentWeek).clamp(1, maxWeek);
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _WeekContent(
                week: week,
                currentWeek: currentWeek,
                maxWeek: maxWeek,
                engine: engine,
                preferences: preferences,
                now: now,
                temporaryWeekendExpanded: temporaryWeekendExpanded,
                onWeekChanged: _selectWeek,
                onEntryTap: (pageWeek, entry) => _showQuickDetail(
                  engine: engine,
                  selectedWeek: pageWeek,
                  entry: entry,
                  hiddenCourseIds: preferences.hiddenCourseIds,
                ),
                onWeekendExpanded: () {
                  setState(() => temporaryWeekendExpanded = true);
                },
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: _ScheduleFabRow(
                  onAdd: () => _showAddSheet(engine: engine, week: week),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectWeek(int week) {
    setState(() {
      selectedWeek = week;
      temporaryWeekendExpanded = false;
    });
  }

  Future<void> _showAddSheet({
    required ScheduleEngine engine,
    required int week,
  }) async {
    final action = await showModalBottomSheet<_AddCourseAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => const _AddCourseSheet(),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _AddCourseAction.manual:
        context.go('/course/new');
      case _AddCourseAction.exception:
        await showStandaloneAddException(
          pageContext: context,
          ref: ref,
          semesterId: engine.semesterId,
          initialDate: engine.weekStart(week),
        );
    }
  }

  Future<void> _showQuickDetail({
    required ScheduleEngine engine,
    required int selectedWeek,
    required ScheduleGridEntry entry,
    required Set<String> hiddenCourseIds,
  }) {
    final semesterSchedule = _cachedTimeslotSchedule(engine, entry);
    return showScheduleQuickDetail(
      context: context,
      engine: engine,
      entry: entry,
      selectedWeek: selectedWeek,
      semesterSchedule: semesterSchedule,
      hiddenCourseIds: hiddenCourseIds,
      onHideCourse: _hideCourseFromWeek,
      onRestoreCourse: _restoreHiddenCourseFromWeek,
    );
  }

  TimeslotSemesterSchedule _cachedTimeslotSchedule(
    ScheduleEngine engine,
    ScheduleGridEntry entry,
  ) {
    if (!identical(_timeslotCacheEngine, engine)) {
      _timeslotCacheEngine = engine;
      _timeslotCache.clear();
    }
    final key = (entry.weekday, entry.startSection, entry.endSection);
    return _timeslotCache.putIfAbsent(
      key,
      () => TimeslotSemesterScheduleBuilder.build(
        engine: engine,
        weekday: entry.weekday,
        startSection: entry.startSection,
        endSection: entry.endSection,
      ),
    );
  }

  void _scheduleNextClockTick() {
    final localNow = DateTime.now();
    final elapsedMinute = Duration(
      seconds: localNow.second,
      milliseconds: localNow.millisecond,
    );
    final delay = const Duration(minutes: 1) - elapsedMinute;
    _clockTimer = Timer(delay, () {
      if (!mounted || widget.now != null) return;
      setState(() => _liveNow = DateTime.now().toUtc());
      _scheduleNextClockTick();
    });
  }

  Future<void> _hideCourseFromWeek(EffectiveCourseInstance instance) async {
    await _setCourseHidden(instance.course.id, hidden: true);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('已隐藏“${instance.courseName}”'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            unawaited(_setCourseHidden(instance.course.id, hidden: false));
          },
        ),
      ),
    );
  }

  Future<void> _restoreHiddenCourseFromWeek(
    EffectiveCourseInstance instance,
  ) async {
    await _setCourseHidden(instance.course.id, hidden: false);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('已恢复“${instance.courseName}”'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            unawaited(_setCourseHidden(instance.course.id, hidden: true));
          },
        ),
      ),
    );
  }

  Future<void> _setCourseHidden(String courseId, {required bool hidden}) async {
    final repository = ref.read(scheduleDataRepositoryProvider);
    final key = scheduleDisplaySettingKeys['hiddenCourseIds']!;
    final hiddenCourseIds = decodeHiddenCourseIds(
      await repository.getSetting(key),
    ).toSet();
    if (hidden) {
      hiddenCourseIds.add(courseId);
    } else {
      hiddenCourseIds.remove(courseId);
    }
    await repository.setSetting(key, encodeHiddenCourseIds(hiddenCourseIds));
    ref.invalidate(scheduleDisplayPreferencesProvider);
  }
}

class _ScheduleFabRow extends StatelessWidget {
  const _ScheduleFabRow({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: '添加课程',
          child: FloatingActionButton.small(
            heroTag: null,
            onPressed: onAdd,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            elevation: 2,
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

class _WeekContent extends StatefulWidget {
  const _WeekContent({
    required this.week,
    required this.currentWeek,
    required this.maxWeek,
    required this.engine,
    required this.preferences,
    required this.now,
    required this.temporaryWeekendExpanded,
    required this.onWeekChanged,
    required this.onEntryTap,
    required this.onWeekendExpanded,
  });

  final int week;
  final int currentWeek;
  final int maxWeek;
  final ScheduleEngine engine;
  final ScheduleDisplayPreferences preferences;
  final DateTime now;
  final bool temporaryWeekendExpanded;
  final ValueChanged<int> onWeekChanged;
  final void Function(int week, ScheduleGridEntry entry) onEntryTap;
  final VoidCallback onWeekendExpanded;

  @override
  State<_WeekContent> createState() => _WeekContentState();
}

class _WeekContentState extends State<_WeekContent> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.week - 1);
  }

  @override
  void didUpdateWidget(covariant _WeekContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.week != widget.week &&
        _pageController.hasClients &&
        (_pageController.page ?? 0).round() != widget.week - 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.animateToPage(
            widget.week - 1,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
          child: WeekPageHeader(
            week: widget.week,
            currentWeek: widget.currentWeek,
            maxWeek: widget.maxWeek,
            definition: widget.engine.calendarDefinition,
            showBackToCurrentWeek:
                widget.preferences.showBackToCurrentWeekFab &&
                    widget.week != widget.currentWeek,
            onBackToCurrentWeek: () => widget.onWeekChanged(widget.currentWeek),
            onWeekChanged: widget.onWeekChanged,
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.maxWeek,
            onPageChanged: (page) {
              final nextWeek = page + 1;
              if (nextWeek != widget.week) widget.onWeekChanged(nextWeek);
            },
            itemBuilder: (context, index) {
              final pageWeek = index + 1;
              final unfilteredModel = widget.engine.getWeekViewModel(
                pageWeek,
                includeInactive: widget.preferences.showInactiveCourses,
                now: widget.now,
              );
              final visibleModel = ScheduleWeekDisplayFilter.hideCourses(
                unfilteredModel,
                widget.preferences.hiddenCourseIds,
              );
              final pageModel =
                  ScheduleWeekDisplayFilter.hideConflictingInactive(
                visibleModel,
              );
              final showWeekend = widget.preferences.showWeekend ||
                  (widget.temporaryWeekendExpanded && pageWeek == widget.week);
              final visibleDays = showWeekend
                  ? pageModel.days
                  : pageModel.days.take(5).toList(growable: false);
              final hasWeekendCourse = pageModel.hasHiddenWeekendCourses;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 96),
                child: Column(
                  children: [
                    if (!showWeekend && hasWeekendCourse)
                      WeekendCourseNotice(
                        message: weekendCourseNoticeMessage(pageModel),
                        onPressed: widget.onWeekendExpanded,
                      ),
                    ScheduleWeekGrid(
                      visibleDays: visibleDays,
                      viewModel: pageModel,
                      preferences: widget.preferences,
                      now: CampusClock.toCampusWallTime(widget.now),
                      onEntryTap: (entry) => widget.onEntryTap(pageWeek, entry),
                    ),
                    if (pageModel.activeEntries.isEmpty) ...[
                      const SizedBox(height: 24),
                      const Text('本周暂无课程'),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class WeekPageHeader extends StatelessWidget {
  const WeekPageHeader({
    required this.week,
    required this.currentWeek,
    required this.maxWeek,
    required this.definition,
    required this.showBackToCurrentWeek,
    required this.onBackToCurrentWeek,
    required this.onWeekChanged,
    super.key,
  });

  final int week;
  final int currentWeek;
  final int maxWeek;
  final CalendarDefinition definition;
  final bool showBackToCurrentWeek;
  final VoidCallback onBackToCurrentWeek;
  final ValueChanged<int> onWeekChanged;

  @override
  Widget build(BuildContext context) {
    final start = definition.weekStart(week);
    final end = start.add(const Duration(days: 6));
    final dateRange = '${start.month}/${start.day} - '
        '${end.month}/${end.day}';
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: Text(
              dateRange,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (showBackToCurrentWeek)
            TextButton(
              onPressed: onBackToCurrentWeek,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text('回到第$currentWeek周'),
            ),
          const SizedBox(width: 4),
          Semantics(
            button: true,
            label: '选择教学周，当前第$week周',
            child: FilledButton.tonalIcon(
              onPressed: () => _openPicker(context),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.keyboard_arrow_down, size: 17),
              label: Text(
                '第$week周${week == currentWeek ? ' · 本周' : ''}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => TeachingWeekPicker(
        selectedWeek: week,
        currentWeek: currentWeek,
        maxWeek: maxWeek,
        definition: definition,
      ),
    );
    if (selected != null) onWeekChanged(selected);
  }
}

class TeachingWeekPicker extends StatelessWidget {
  const TeachingWeekPicker({
    required this.selectedWeek,
    required this.currentWeek,
    required this.maxWeek,
    required this.definition,
    super.key,
  });

  final int selectedWeek;
  final int currentWeek;
  final int maxWeek;
  final CalendarDefinition definition;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: (MediaQuery.sizeOf(context).height * .72).clamp(280, 620),
        child: ListView.builder(
          itemCount: maxWeek + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return const ListTile(
                title: Text(
                  '选择教学周',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              );
            }
            final item = index;
            final start = definition.weekStart(item);
            final end = start.add(const Duration(days: 6));
            return ListTile(
              selected: item == selectedWeek,
              leading: SizedBox(
                width: 32,
                child: item == selectedWeek
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
              title: Text('第$item周'),
              subtitle: Text(
                '${start.month}/${start.day} – ${end.month}/${end.day}'
                '${item == currentWeek ? ' · 本周' : ''}',
              ),
              onTap: () => Navigator.of(context).pop(item),
            );
          },
        ),
      ),
    );
  }
}

class WeekendCourseNotice extends StatelessWidget {
  const WeekendCourseNotice({
    required this.message,
    required this.onPressed,
    super.key,
  });

  final String message;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.only(left: 10, right: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('查看周末 ›'),
          ),
        ],
      ),
    );
  }
}

String weekendCourseNoticeMessage(WeekScheduleViewModel model) {
  final activeWeekendDays = model.entries
      .where((entry) => entry.active && entry.weekday >= DateTime.saturday)
      .map((entry) => entry.weekday)
      .toSet();
  final makeupDays = model.days.where(
    (day) =>
        day.kind == ScheduleDayKind.makeup &&
        activeWeekendDays.contains(day.weekday),
  );
  if (makeupDays.length == 1) {
    return '本周${makeupDays.single.label}有补课安排';
  }
  if (makeupDays.isNotEmpty) return '本周周末有补课安排';
  return '本周周末有 ${model.activeWeekendCount} 节课';
}

enum _AddCourseAction { manual, exception }

class _AddCourseSheet extends StatelessWidget {
  const _AddCourseSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            '添加课程',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('手动添加课程'),
            subtitle: const Text('创建长期课程及上课安排'),
            onTap: () => Navigator.of(context).pop(_AddCourseAction.manual),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_repeat_outlined),
            title: const Text('临时加课'),
            subtitle: const Text('仅修改指定日期的实际课表'),
            onTap: () => Navigator.of(context).pop(_AddCourseAction.exception),
          ),
        ],
      ),
    );
  }
}

class _ScheduleEmptyState extends StatelessWidget {
  const _ScheduleEmptyState({required this.onImport, required this.onManual});

  final VoidCallback onImport;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无课表',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('可以从教务系统导入，或先手动添加课程。'),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onImport,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('从教务系统导入'),
                ),
                OutlinedButton.icon(
                  onPressed: onManual,
                  icon: const Icon(Icons.add),
                  label: const Text('手动添加'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
