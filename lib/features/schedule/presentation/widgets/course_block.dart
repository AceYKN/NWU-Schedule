import 'package:flutter/material.dart';

import '../../../../domain/course/course_exception.dart';
import '../../../../domain/schedule/week_schedule_view_model.dart';
import '../../../../domain/settings/schedule_display_preferences.dart';
import '../../../shared/presentation/course_card.dart';
import '../../../shared/presentation/course_color_resolver.dart';
import 'course_display_formatter.dart';

/// Compatibility wrapper kept for callers and tests that refer to the old
/// name. The actual presentation component is [CourseEventCard].
class CourseBlock extends StatelessWidget {
  const CourseBlock({
    required this.entry,
    required this.preferences,
    required this.width,
    required this.height,
    required this.visibleDayCount,
    this.isCurrent = false,
    super.key,
  });

  final ScheduleGridEntry entry;
  final ScheduleDisplayPreferences preferences;
  final double width;
  final double height;
  final int visibleDayCount;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return CourseEventCard(
      entry: entry,
      preferences: preferences,
      width: width,
      height: height,
      visibleDayCount: visibleDayCount,
      isCurrent: isCurrent,
    );
  }
}

class CourseEventCard extends StatelessWidget {
  const CourseEventCard({
    required this.entry,
    required this.preferences,
    required this.width,
    required this.height,
    required this.visibleDayCount,
    this.isCurrent = false,
    super.key,
  });

  final ScheduleGridEntry entry;
  final ScheduleDisplayPreferences preferences;
  final double width;
  final double height;
  final int visibleDayCount;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = CourseColorResolver.resolveSchedule(entry.course, scheme);
    final ghost = !entry.active;
    final status = _statusLabel(entry.exceptionType);
    final title = CourseDisplayFormatter.title(entry.course.name);
    final location = CourseDisplayFormatter.location(entry);
    final foreground = ghost
        ? scheme.onSurfaceVariant.withValues(alpha: .48)
        : colors.onContainer;
    final background = ghost ? Colors.transparent : colors.container;
    final border = ghost
        ? BorderSide(color: scheme.outlineVariant.withValues(alpha: .48))
        : isCurrent
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none;
    final label = CourseDisplayFormatter.semanticsLabel(entry);

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '$label，点击查看课程详情',
      onTap: () => showCourseDetails(context, entry.instance),
      child: Material(
        color: background,
        elevation: isCurrent && !ghost ? 1 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: border,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showCourseDetails(context, entry.instance),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                color: ghost
                    ? scheme.outlineVariant.withValues(alpha: .42)
                    : colors.onContainer.withValues(alpha: .72),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: visibleDayCount >= 7 || width < 68 ? 4 : 6,
                    vertical: visibleDayCount >= 7 || width < 68 ? 4 : 5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _line(
                              title,
                              foreground,
                              title: true,
                              maxLines: height >= 92 && width >= 58 ? 2 : 1,
                            ),
                          ),
                          if (status != null) ...[
                            const SizedBox(width: 2),
                            _StatusBadge(
                              label: status.label,
                              color: status.color(scheme),
                            ),
                          ],
                        ],
                      ),
                      if (!ghost && height >= 52 && location != null)
                        _line(location, foreground, title: false),
                      if (!ghost &&
                          height >= 92 &&
                          preferences.showTeacher &&
                          entry.teacher != null &&
                          entry.teacher!.trim().isNotEmpty)
                        _line(
                          entry.teacher!.trim(),
                          foreground.withValues(alpha: .78),
                          title: false,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(
    String value,
    Color color, {
    required bool title,
    int maxLines = 1,
  }) {
    final compact = width < 58;
    return Text(
      value,
      maxLines: compact ? 1 : maxLines,
      softWrap: !compact && maxLines > 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: title ? (compact ? 10.5 : 12) : (compact ? 9 : 10),
        height: title ? 1.12 : 1.15,
        fontWeight: title ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  _CourseStatus? _statusLabel(CourseExceptionType? type) {
    return switch (type) {
      CourseExceptionType.add => const _CourseStatus('加', _StatusKind.add),
      CourseExceptionType.move => const _CourseStatus('调', _StatusKind.move),
      CourseExceptionType.cancel =>
        const _CourseStatus('停', _StatusKind.cancel),
      null => null,
    };
  }
}

class OverflowCourseBlock extends StatelessWidget {
  const OverflowCourseBlock({
    required this.entries,
    required this.height,
    super.key,
  });

  final List<ScheduleGridEntry> entries;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = '+${entries.length}';
    return Semantics(
      button: true,
      label: '同一时段还有 ${entries.length} 门课程',
      onTap: () => _showEntries(context),
      child: Material(
        color: scheme.secondaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showEntries(context),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontSize: height < 52 ? 11 : 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEntries(BuildContext context) async {
    final selected = await showModalBottomSheet<ScheduleGridEntry>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            Text(
              '同一时段的其他课程',
              style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            for (final entry in entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(CourseDisplayFormatter.title(entry.course.name)),
                subtitle: Text(
                  [
                    '第${entry.startSection}-${entry.endSection}节',
                    if (entry.room != null) entry.room!,
                    if (entry.teacher != null) entry.teacher!,
                  ].join(' · '),
                ),
                onTap: () => Navigator.of(sheetContext).pop(entry),
              ),
          ],
        ),
      ),
    );
    if (context.mounted && selected != null) {
      showCourseDetails(context, selected.instance);
    }
  }
}

enum _StatusKind { add, move, cancel }

class _CourseStatus {
  const _CourseStatus(this.label, this.kind);

  final String label;
  final _StatusKind kind;

  Color color(ColorScheme scheme) {
    return switch (kind) {
      _StatusKind.add => scheme.tertiary,
      _StatusKind.move => scheme.secondary,
      _StatusKind.cancel => scheme.error,
    };
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          height: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
