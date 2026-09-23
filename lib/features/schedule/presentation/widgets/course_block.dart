import 'package:flutter/material.dart';

import '../../../../app/theme/schedule_theme.dart';
import '../../../../domain/course/course_exception.dart';
import '../../../../domain/schedule/week_schedule_view_model.dart';
import '../../../../domain/settings/schedule_display_preferences.dart';
import 'course_block_density.dart';
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
    this.onTap,
    super.key,
  });

  final ScheduleGridEntry entry;
  final ScheduleDisplayPreferences preferences;
  final double width;
  final double height;
  final int visibleDayCount;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CourseEventCard(
      entry: entry,
      preferences: preferences,
      width: width,
      height: height,
      visibleDayCount: visibleDayCount,
      isCurrent: isCurrent,
      onTap: onTap,
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
    this.onTap,
    super.key,
  });

  final ScheduleGridEntry entry;
  final ScheduleDisplayPreferences preferences;
  final double width;
  final double height;
  final int visibleDayCount;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = CourseColorResolver.resolveSchedule(entry.course, scheme);
    final ghost = !entry.active;
    final status = _statusLabel(entry.exceptionType);
    final tokens = scheduleThemeTokensOf(context);
    final density = resolveCourseBlockDensity(
      width: width,
      height: height,
      visibleDayCount: visibleDayCount,
    );
    final title = CourseDisplayFormatter.title(entry.course.name);
    final location = density == CourseBlockDensity.roomy
        ? CourseDisplayFormatter.location(entry)
        : CourseDisplayFormatter.compactLocation(entry);
    final background = ghost
        ? Color.lerp(scheme.surface, colors.container, .38)!
        : colors.container;
    final foreground = ghost
        ? Color.lerp(background, colors.onContainer, .75)!
        : colors.onContainer;
    final secondaryForeground = ghost
        ? Color.lerp(background, colors.onContainer, .62)!
        : foreground.withValues(alpha: .78);
    final border = ghost
        ? BorderSide(color: colors.onContainer.withValues(alpha: .40))
        : isCurrent
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none;
    final label = CourseDisplayFormatter.semanticsLabel(entry);
    final showDetails = height >= 46;
    final showTeacher = density != CourseBlockDensity.dense &&
        height >= 60 &&
        preferences.showTeacher &&
        entry.teacher != null &&
        entry.teacher!.trim().isNotEmpty;
    final titleMaxLines = height < 36 ? 1 : (height >= 100 ? 3 : 2);
    final compact = density != CourseBlockDensity.roomy;

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '$label，点击查看课程详情',
      onTap: () => _handleTap(context),
      child: Material(
        color: background,
        elevation: isCurrent && !ghost ? 1 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          side: border,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _handleTap(context),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 4 : 6,
              vertical: height < 36 ? 1 : (compact ? 3 : 4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _wrappedLine(
                        title,
                        foreground,
                        title: true,
                        maxLines: titleMaxLines,
                        fontSize: tokens.denseTitleSize,
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
                if (showDetails && location != null) ...[
                  const SizedBox(height: 1),
                  _wrappedLine(
                    location,
                    secondaryForeground,
                    maxLines: compact ? 1 : null,
                    fontSize: tokens.denseDetailSize,
                  ),
                ],
                if (showDetails && showTeacher) ...[
                  const SizedBox(height: 1),
                  _wrappedLine(
                    entry.teacher!.trim(),
                    secondaryForeground,
                    maxLines:
                        density == CourseBlockDensity.roomy && height >= 100
                            ? 2
                            : 1,
                    fontSize: tokens.denseDetailSize,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _wrappedLine(
    String value,
    Color color, {
    bool title = false,
    required int? maxLines,
    required double fontSize,
  }) {
    return Text(
      value,
      maxLines: maxLines,
      softWrap: true,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        height: title ? 1.16 : 1.2,
        fontWeight: title ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  void _handleTap(BuildContext context) {
    if (onTap != null) {
      onTap!();
    } else {
      showCourseDetails(context, entry.instance);
    }
  }

  _CourseStatus? _statusLabel(CourseExceptionType? type) {
    return switch (type) {
      CourseExceptionType.add => const _CourseStatus('加', _StatusKind.add),
      CourseExceptionType.move => const _CourseStatus('调', _StatusKind.move),
      CourseExceptionType.cancel => const _CourseStatus(
          '停',
          _StatusKind.cancel,
        ),
      null => null,
    };
  }
}

class OverflowCourseBlock extends StatelessWidget {
  const OverflowCourseBlock({
    required this.entries,
    required this.height,
    this.onEntryTap,
    super.key,
  });

  final List<ScheduleGridEntry> entries;
  final double height;
  final ValueChanged<ScheduleGridEntry>? onEntryTap;

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
          borderRadius: BorderRadius.circular(
            scheduleThemeTokensOf(context).radiusMedium,
          ),
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
              style: Theme.of(sheetContext)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
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
      if (onEntryTap != null) {
        onEntryTap!(selected);
      } else {
        showCourseDetails(context, selected.instance);
      }
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
        borderRadius: BorderRadius.circular(
          scheduleThemeTokensOf(context).radiusSmall,
        ),
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
