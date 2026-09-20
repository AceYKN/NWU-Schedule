import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/bootstrap.dart';
import '../../../core/nwu/constants.dart';
import '../../../domain/import/import_diff.dart';
import '../../../domain/import/timetable_import.dart';
import '../../../domain/import/timetable_importer.dart';
import '../../../domain/import/three_way_merge.dart';
import '../../../domain/errors/app_error.dart';
import '../../../infrastructure/backup/backup_file_service.dart';
import '../../../infrastructure/import/nwu_zhengfang_v9_importer.dart';
import '../../../infrastructure/import/webview_session_service.dart';

class TimetableImportPage extends ConsumerStatefulWidget {
  const TimetableImportPage({super.key});

  @override
  ConsumerState<TimetableImportPage> createState() =>
      _TimetableImportPageState();
}

class _TimetableImportPageState extends ConsumerState<TimetableImportPage> {
  static const _bridgeName = 'nwuScheduleBridge';
  static const _maxPayloadCharacters = 2 * 1024 * 1024;
  static const _payloadSelectors = [
    'window.__NWU_SCHEDULE_PAYLOAD__',
    'window.__NWU_TIMETABLE__',
    'window.nwuSchedulePayload',
    'table',
  ];

  late final WebViewController _controller;
  final _cookieManager = WebViewCookieManager();
  RemoteTimetable? _timetable;
  ImportDiff? _diff;
  ImportConflictResolution _resolution = ImportConflictResolution.empty;
  ImportDiagnostic? _diagnostic;
  String? _error;
  String? _currentUrl;
  int? _lastHttpStatus;
  bool _bridgeEnabled = false;
  bool _reading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null || !NwuZhengfangV9Importer.isAllowedUri(uri)) {
              _setError('已阻止非西北大学教务域名的页面');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (url) {
            if (mounted) setState(() => _currentUrl = url);
          },
          onPageFinished: (url) => _onPageFinished(url),
          onWebResourceError: (error) {
            unawaited(_recordWebResourceError(error));
          },
          onHttpError: _recordHttpError,
        ),
      )
      ..loadRequest(NwuZhengfangV9Importer.entryUri);
  }

  @override
  void dispose() {
    unawaited(_clearSession());
    super.dispose();
  }

  Future<void> _onPageFinished(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !NwuZhengfangV9Importer.isAllowedUri(uri)) return;
    if (mounted) setState(() => _currentUrl = url);
    final isLoginPage = uri.path.contains('login') ||
        uri.path.contains('sso') ||
        uri.path.contains('auth');
    if (isLoginPage) {
      if (_bridgeEnabled) {
        await _controller.removeJavaScriptChannel(_bridgeName);
        _bridgeEnabled = false;
      }
      return;
    }
    if (_bridgeEnabled) return;
    await _controller.addJavaScriptChannel(
      _bridgeName,
      onMessageReceived: (message) => _handleBridgeMessage(message.message),
    );
    _bridgeEnabled = true;
  }

  Future<Map<String, dynamic>> _readPayload() async {
    if (!_bridgeEnabled) {
      throw const FormatException('登录完成后请先打开课表页面');
    }
    final result = await _controller.runJavaScriptReturningResult(
      _payloadExtractionScript,
    );
    final payload = _decodePayload(result);
    if (payload == null) {
      throw const FormatException(
        '当前页面没有暴露可识别的课表数据，请打开个人课表页面后重试',
      );
    }
    return payload;
  }

  Future<void> _readCurrentPage() async {
    if (_reading) return;
    setState(() {
      _reading = true;
      _error = null;
      _diagnostic = null;
      _lastHttpStatus = null;
      _diff = null;
      _resolution = ImportConflictResolution.empty;
    });
    final importer = NwuZhengfangV9Importer(readPayload: _readPayload);
    try {
      final semesters = await importer.getSemesters();
      final selected = await _selectRemoteSemester(semesters);
      if (selected == null) return;
      final timetable = await importer.importSemester(selected);
      final diff = await _buildDiff(timetable);
      if (!mounted) return;
      setState(() {
        _timetable = timetable;
        _diff = diff;
        _resolution = ImportConflictResolution.empty;
      });
    } on TimetableImportFailure catch (error) {
      _setFailure(
        importFailureUserMessage(error),
        await _enrichDiagnostic(error.diagnostic),
      );
    } on Object catch (error) {
      _setFailure(
        nwuUserMessage(error, action: '无法读取课表'),
        await _enrichDiagnostic(ImportDiagnostic(
          adapterVersion: 'nwu-zhengfang-v9',
          parserStage: 'webview-read',
          currentUrlPath: _currentUrlPath,
          error: redactImportError(error),
        )),
      );
    } finally {
      await importer.dispose();
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<RemoteSemester?> _selectRemoteSemester(
    List<RemoteSemester> semesters,
  ) async {
    if (semesters.isEmpty) {
      throw const FormatException('教务系统没有可导入的学期');
    }
    if (semesters.length == 1) return semesters.single;
    if (!mounted) return null;
    return showModalBottomSheet<RemoteSemester>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('选择要导入的学期'),
              subtitle: Text('课表读取完成后才会写入本地数据'),
            ),
            ...semesters.map(
              (semester) => ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(semester.label),
                subtitle: Text(semester.remoteTermKey),
                onTap: () => Navigator.pop(sheetContext, semester),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBridgeMessage(String message) {
    unawaited(_handleBridgeMessageAsync(message));
  }

  Future<void> _handleBridgeMessageAsync(String message) async {
    try {
      if (message.length > _maxPayloadCharacters) {
        throw const FormatException('课表桥接数据超过大小限制');
      }
      final decoded = jsonDecode(message);
      final payload = decoded is Map && decoded['payload'] is Map
          ? Map<String, dynamic>.from(decoded['payload'] as Map)
          : decoded is Map
              ? Map<String, dynamic>.from(decoded)
              : null;
      if (payload == null) throw const FormatException('桥接消息不是对象');
      final timetable = const TimetableImportParser().parse(payload);
      final report = validateTimetable(timetable);
      if (!report.isValid) throw FormatException(report.issues.join('; '));
      final diff = await _buildDiff(timetable);
      if (mounted) {
        setState(() {
          _timetable = timetable;
          _diff = diff;
          _resolution = ImportConflictResolution.empty;
          _error = null;
          _diagnostic = null;
        });
      }
    } on Object catch (error) {
      _setFailure(
        nwuUserMessage(error, action: '课表桥接数据无效'),
        await _enrichDiagnostic(ImportDiagnostic(
          adapterVersion: 'nwu-zhengfang-v9',
          parserStage: 'bridge-message',
          currentUrlPath: _currentUrlPath,
          error: redactImportError(error),
        )),
      );
    }
  }

  Future<void> _confirmImport() async {
    final timetable = _timetable;
    final diff = _resolvedDiff;
    if (timetable == null || diff == null || _saving || diff.hasConflicts) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(scheduleDataRepositoryProvider).commitImportedTimetable(
            timetable,
            adapterVersion: 'nwu-zhengfang-v9',
            resolution: _resolution,
          );
      ref.invalidate(scheduleLoadProvider);
      if (mounted) context.go('/');
    } on TimetableImportConflictException {
      _setError('发现本地与教务系统同时修改的课程，导入已取消，未写入部分数据');
    } on Object catch (error) {
      _setError(nwuUserMessage(error, action: '确认导入失败'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportDiagnostic() async {
    final diagnostic = _diagnostic;
    if (diagnostic == null) return;
    try {
      final saved = await const BackupFileService().save(
        jsonEncode({
          'format': 'nwu-schedule-diagnostic',
          'schemaVersion': 1,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'diagnostic': diagnostic.toJson(),
        }),
        suggestedName: 'nwu-schedule-diagnostic.json',
      );
      if (mounted) _showMessage(saved ? '诊断信息已导出' : '已取消导出');
    } on Object catch (error) {
      if (mounted) _showMessage(nwuUserMessage(error, action: '诊断导出失败'));
    }
  }

  void _setError(String message) {
    if (mounted) setState(() => _error = message);
  }

  Future<void> _recordWebResourceError(WebResourceError error) async {
    final failure = TimetableImportFailure(
      '教务页面加载失败',
      ImportDiagnostic(
        adapterVersion: 'nwu-zhengfang-v9',
        parserStage: 'web-resource',
        currentUrlPath: _currentUrlPath,
        error: redactImportError(error.description),
      ),
    );
    _setFailure(
      importFailureUserMessage(failure),
      await _enrichDiagnostic(failure.diagnostic),
    );
  }

  void _recordHttpError(HttpResponseError error) {
    final response = error.response;
    final uri = response?.uri;
    if (response == null || uri == null) return;
    if (NwuZhengfangV9Importer.isAllowedUri(uri)) {
      _lastHttpStatus = response.statusCode;
    }
  }

  void _setFailure(String message, ImportDiagnostic diagnostic) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _diagnostic = diagnostic;
      _timetable = null;
      _diff = null;
      _resolution = ImportConflictResolution.empty;
    });
  }

  Future<void> _showConflictResolution() async {
    final diff = _diff;
    if (diff == null || (!diff.hasConflicts && !diff.hasLocallyDeleted)) {
      return;
    }
    final resolution = await showModalBottomSheet<ImportConflictResolution>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ConflictResolutionSheet(
        diff: diff,
        initial: _resolution,
      ),
    );
    if (!mounted) return;
    setState(() => _resolution = resolution ?? _resolution);
  }

  ImportDiff? get _resolvedDiff {
    final diff = _diff;
    return diff?.resolve(_resolution);
  }

  Future<ImportDiff> _buildDiff(RemoteTimetable timetable) async {
    return ref
        .read(scheduleDataRepositoryProvider)
        .previewImportedTimetable(timetable);
  }

  Future<ImportDiagnostic> _enrichDiagnostic(
    ImportDiagnostic diagnostic,
  ) async {
    String? userAgent;
    try {
      userAgent = await _controller.getUserAgent();
    } on Object {
      // Diagnostics should still be exportable if WebView metadata is absent.
    }
    return diagnostic.copyWith(
      appVersion: nwuAppVersion,
      androidVersion: Platform.operatingSystemVersion,
      webViewVersion: _webViewVersion(userAgent),
      currentUrlPath: _currentUrlPath,
      httpStatus: diagnostic.httpStatus ?? _lastHttpStatus,
      selectors: diagnostic.selectors.isEmpty
          ? _payloadSelectors
          : diagnostic.selectors,
    );
  }

  static String? _webViewVersion(String? userAgent) {
    if (userAgent == null || userAgent.isEmpty) return null;
    return RegExp(r'(?:Chrome|Version)/([0-9.]+)')
            .firstMatch(userAgent)
            ?.group(1) ??
        userAgent;
  }

  String? get _currentUrlPath {
    final uri = _currentUrl == null ? null : Uri.tryParse(_currentUrl!);
    return uri?.path;
  }

  Future<void> _clearSession() async {
    final bridgeWasEnabled = _bridgeEnabled;
    _bridgeEnabled = false;
    if (bridgeWasEnabled) {
      await _bestEffort(() => _controller.removeJavaScriptChannel(_bridgeName));
    }
    await _bestEffort(
      () => _controller.runJavaScript(
        'try { localStorage.clear(); sessionStorage.clear(); '
        'document.querySelectorAll("input").forEach((e) => e.value = ""); } catch (_) {}',
      ),
    );
    await _bestEffort(_controller.clearLocalStorage);
    await _bestEffort(_controller.clearCache);
    await _bestEffort(() async {
      await _cookieManager.clearCookies();
    });
    await _bestEffort(const WebViewSessionService().clear);
  }

  Future<void> _bestEffort(Future<void> Function() operation) async {
    try {
      await operation();
    } on Object {
      // Cleanup continues independently when the WebView is already closing.
    }
  }

  @override
  Widget build(BuildContext context) {
    final timetable = _timetable;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              IconButton(
                tooltip: '取消',
                onPressed: () => context.pop(),
                icon: const Icon(Icons.close),
              ),
              Expanded(
                child: Text(
                  '从教务系统导入',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _reading ? null : _readCurrentPage,
                icon: _reading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: const Text('读取课表'),
              ),
            ],
          ),
        ),
        if (_error != null)
          MaterialBanner(
            content: Text(_error!),
            leading: const Icon(Icons.error_outline),
            actions: [
              if (_diagnostic != null)
                TextButton(
                  onPressed: _exportDiagnostic,
                  child: const Text('导出诊断'),
                ),
              TextButton(
                onPressed: () => setState(() => _error = null),
                child: const Text('关闭'),
              ),
            ],
          ),
        Expanded(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (timetable != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _ImportPreview(
                    timetable: timetable,
                    diff: _resolvedDiff,
                    hasConflictItems: _diff?.hasConflicts == true ||
                        _diff?.hasLocallyDeleted == true,
                    saving: _saving,
                    onConfirm: _confirmImport,
                    onRetry: _readCurrentPage,
                    onCancel: () => setState(() {
                      _timetable = null;
                      _diff = null;
                      _resolution = ImportConflictResolution.empty;
                    }),
                    onResolveConflicts: _showConflictResolution,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ImportPreview extends StatelessWidget {
  const _ImportPreview({
    required this.timetable,
    required this.diff,
    required this.saving,
    required this.hasConflictItems,
    required this.onConfirm,
    required this.onRetry,
    required this.onCancel,
    required this.onResolveConflicts,
  });

  final RemoteTimetable timetable;
  final ImportDiff? diff;
  final bool hasConflictItems;
  final bool saving;
  final VoidCallback onConfirm;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final VoidCallback onResolveConflicts;

  @override
  Widget build(BuildContext context) {
    final meetingCount = timetable.courses.fold<int>(
      0,
      (total, course) => total + course.meetings.length,
    );
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '读取完成 · ${timetable.semester.label}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text('${timetable.courses.length} 门课程 · $meetingCount 个上课安排'),
            if (diff != null) ...[
              const SizedBox(height: 4),
              if (diff!.isNewSemester)
                const Text(
                  '发现新的学期，确认后会建立独立的本地课表，不会覆盖其他学期。',
                ),
              Text(
                '新增 ${diff!.addedCount} · 更新 ${diff!.modifiedCount} · '
                '删除 ${diff!.removedCount} · '
                '本地删除 ${diff!.locallyDeletedCount} · '
                '冲突 ${diff!.conflictCount}',
                style: TextStyle(
                  color: diff!.hasConflicts
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
              if (diff!.hasConflicts)
                Text(
                  '检测到本地与远端同时修改，请先解决冲突后再确认导入。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              if (hasConflictItems)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onResolveConflicts,
                    icon: const Icon(Icons.merge_type),
                    label: Text(
                      diff!.hasConflicts ? '解决冲突' : '处理本地删除课程',
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            ...timetable.courses.take(3).map(
                  (course) => Text(
                    '${course.name} · ${course.meetings.length} 个安排',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            if (timetable.courses.length > 3)
              Text('还有 ${timetable.courses.length - 3} 门课程…'),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onCancel, child: const Text('取消')),
                TextButton(onPressed: onRetry, child: const Text('重新读取')),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed:
                      saving || diff == null || diff?.hasConflicts == true
                          ? null
                          : onConfirm,
                  child: Text(
                    saving
                        ? '导入中…'
                        : diff?.isNewSemester == true
                            ? '建立新课表'
                            : '确认导入',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConflictEntry {
  const _ConflictEntry(this.change, this.field);

  final ImportChange change;
  final ImportFieldChange field;
}

class _ConflictResolutionSheet extends StatefulWidget {
  const _ConflictResolutionSheet({
    required this.diff,
    required this.initial,
  });

  final ImportDiff diff;
  final ImportConflictResolution initial;

  @override
  State<_ConflictResolutionSheet> createState() =>
      _ConflictResolutionSheetState();
}

class _ConflictResolutionSheetState extends State<_ConflictResolutionSheet> {
  late final Map<String, Map<String, MergeDecision>> _choices = {
    for (final entry in widget.initial.choices.entries)
      entry.key: Map<String, MergeDecision>.from(entry.value),
  };
  late final Set<String> _restoreDeleted = {
    ...widget.initial.restoreDeletedCourseKeys,
  };

  List<_ConflictEntry> get _entries => [
        for (final change in widget.diff.changes)
          for (final field in change.fields)
            if (field.hasConflict) _ConflictEntry(change, field),
      ];

  List<ImportChange> get _deletedChanges => [
        for (final change in widget.diff.changes)
          if (change.kind == ImportChangeKind.locallyDeleted) change,
      ];

  bool get _complete => _entries.every(
        (entry) =>
            _choices[entry.change.sourceCourseKey]?[entry.field.field] != null,
      );

  void _choose(_ConflictEntry entry, MergeDecision decision) {
    final next = Map<String, MergeDecision>.from(
      _choices[entry.change.sourceCourseKey] ?? const {},
    );
    next[entry.field.field] = decision;
    setState(() => _choices[entry.change.sourceCourseKey] = next);
  }

  void _toggleRestore(ImportChange change, bool restore) {
    setState(() {
      if (restore) {
        _restoreDeleted.add(change.sourceCourseKey);
      } else {
        _restoreDeleted.remove(change.sourceCourseKey);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '处理导入变更',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              const Text('本地删除默认保留；冲突字段和恢复动作都由你明确选择。'),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: _deletedChanges.length + entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index < _deletedChanges.length) {
                      final change = _deletedChanges[index];
                      final courseName =
                          change.remoteCourse?.name ?? change.sourceCourseKey;
                      return Card(
                        child: CheckboxListTile(
                          value: _restoreDeleted.contains(
                            change.sourceCourseKey,
                          ),
                          onChanged: (value) => _toggleRestore(
                            change,
                            value ?? false,
                          ),
                          title: Text('恢复 $courseName'),
                          subtitle: const Text('教务系统中仍存在这门课程，勾选后本次导入会恢复它。'),
                          secondary: const Icon(Icons.restore),
                        ),
                      );
                    }
                    final entry = entries[index - _deletedChanges.length];
                    final selected = _choices[entry.change.sourceCourseKey]
                        ?[entry.field.field];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              dense: true,
                              title: Text(
                                '${entry.change.remoteCourse?.name ?? entry.change.sourceCourseKey} · ${_fieldLabel(entry.field.field)}',
                              ),
                              subtitle: Text(
                                '本地：${_displayValue(entry.field.localValue, entry.field.field)}\n'
                                '教务：${_displayValue(entry.field.remoteValue, entry.field.field)}',
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: SegmentedButton<MergeDecision>(
                                segments: const [
                                  ButtonSegment(
                                    value: MergeDecision.local,
                                    label: Text('保留本地'),
                                  ),
                                  ButtonSegment(
                                    value: MergeDecision.remote,
                                    label: Text('采用教务'),
                                  ),
                                ],
                                selected: {
                                  if (selected != null) selected,
                                },
                                onSelectionChanged: (selection) {
                                  if (selection.isNotEmpty) {
                                    _choose(entry, selection.first);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _complete
                      ? () => Navigator.of(context).pop(
                            ImportConflictResolution.copy(
                              _choices,
                              restoreDeletedCourseKeys: _restoreDeleted,
                            ),
                          )
                      : null,
                  child: Text(_complete ? '应用选择' : '请完成全部选择'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _fieldLabel(String field) => switch (field) {
      'name' => '课程名',
      'code' => '课程代码',
      'teachingClass' => '教学班',
      'credits' => '学分',
      'assessment' => '考核方式',
      'meetings' => '上课安排',
      _ => field,
    };

String _displayValue(Object? value, String field) {
  if (value == null) return '未填写';
  if (field == 'meetings' && value is List) return '${value.length} 个上课安排';
  return value.toString();
}

Map<String, dynamic>? _decodePayload(Object? result) {
  if (result is! String) return null;
  if (result.length > _TimetableImportPageState._maxPayloadCharacters) {
    return null;
  }
  try {
    final first = jsonDecode(result);
    if (first is Map) return Map<String, dynamic>.from(first);
    if (first is String) {
      final second = jsonDecode(first);
      if (second is Map) return Map<String, dynamic>.from(second);
    }
  } on Object {
    return null;
  }
  return null;
}

const _payloadExtractionScript = r'''(() => {
  const candidates = [
    window.__NWU_SCHEDULE_PAYLOAD__,
    window.__NWU_TIMETABLE__,
    window.nwuSchedulePayload,
  ];
  for (const candidate of candidates) {
    if (candidate == null) continue;
    try {
      return JSON.stringify(typeof candidate === 'string' ? JSON.parse(candidate) : candidate);
    } catch (_) {}
  }
  const bodyText = document.body ? document.body.innerText : '';
  const year = bodyText.match(/(20\d{2})\s*[-—~至]\s*(20\d{2})/);
  const termText = bodyText.match(/第\s*([一二三123])\s*学期/);
  if (!year) return JSON.stringify(null);
  const termMap = { '一': 1, '二': 2, '三': 3, '1': 1, '2': 2, '3': 3 };
  const term = termMap[termText ? termText[1] : '1'] || 1;
  const text = (node) => (node && node.innerText ? node.innerText : '').trim();
  const headerIndex = (headers, patterns) => headers.findIndex((header) =>
    patterns.some((pattern) => header.includes(pattern)));
  const dayNumber = (value) => {
    const match = String(value).match(/[一二三四五六日天1-7]/);
    if (!match) return null;
    return ({ '一': 1, '二': 2, '三': 3, '四': 4, '五': 5,
      '六': 6, '日': 7, '天': 7, '1': 1, '2': 2, '3': 3,
      '4': 4, '5': 5, '6': 6, '7': 7 })[match[0]] || null;
  };
  const sectionRange = (value) => {
    const numbers = String(value).match(/\d+/g) || [];
    if (!numbers.length) return null;
    const start = Number(numbers[0]);
    const end = Number(numbers[1] || numbers[0]);
    return { startSection: Math.min(start, end), endSection: Math.max(start, end) };
  };
  const courses = [];
  let maxWeek = 20;
  for (const table of Array.from(document.querySelectorAll('table'))) {
    const rows = Array.from(table.querySelectorAll('tr'));
    if (!rows.length) continue;
    const headers = Array.from(rows[0].querySelectorAll('th,td')).map(text);
    const nameIndex = headerIndex(headers, ['课程名称', '课程名', '课程']);
    const dayIndex = headerIndex(headers, ['星期', '周几', '上课星期']);
    const sectionIndex = headerIndex(headers, ['节次', '上课节次']);
    const weekIndex = headerIndex(headers, ['周次', '上课周次']);
    if (nameIndex < 0 || dayIndex < 0 || sectionIndex < 0 || weekIndex < 0) continue;
    const codeIndex = headerIndex(headers, ['课程代码', '课程编号', '课程号']);
    const teacherIndex = headerIndex(headers, ['教师', '任课教师', '上课教师']);
    const roomIndex = headerIndex(headers, ['教室', '上课地点', '地点']);
    const classIndex = headerIndex(headers, ['教学班', '班级']);
    const creditIndex = headerIndex(headers, ['学分']);
    const assessmentIndex = headerIndex(headers, ['考核方式', '考试性质']);
    for (let rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      const cells = Array.from(rows[rowIndex].querySelectorAll('td,th')).map(text);
      const name = cells[nameIndex] || '';
      const weekday = dayNumber(cells[dayIndex]);
      const range = sectionRange(cells[sectionIndex]);
      const weekText = cells[weekIndex] || '';
      if (!name || !weekday || !range || !weekText) continue;
      for (const match of weekText.matchAll(/\d+/g)) maxWeek = Math.max(maxWeek, Number(match[0]));
      const code = codeIndex >= 0 ? cells[codeIndex] || null : null;
      const teachingClass = classIndex >= 0 ? cells[classIndex] || null : null;
      const key = code || (name + '|' + (teachingClass || '') + '|' + rowIndex);
      let course = courses.find((item) => item.sourceCourseKey === key);
      if (!course) {
        course = {
          sourceCourseKey: key,
          name: name,
          code: code,
          teachingClass: teachingClass,
          credits: creditIndex >= 0 && cells[creditIndex] ? Number(cells[creditIndex]) : null,
          assessment: assessmentIndex >= 0 ? cells[assessmentIndex] || null : null,
          meetings: [],
        };
        courses.push(course);
      }
      course.meetings.push({
        sourceMeetingKey: key + '|meeting|' + course.meetings.length,
        weekday: weekday,
        startSection: range.startSection,
        endSection: range.endSection,
        teacher: teacherIndex >= 0 ? cells[teacherIndex] || null : null,
        campus: null,
        room: roomIndex >= 0 ? cells[roomIndex] || null : null,
        weekText: weekText,
      });
    }
  }
  if (!courses.length) return JSON.stringify(null);
  const totalWeeks = Math.min(Math.max(maxWeek, 1), 64);
  const academicYear = year[1] + '-' + year[2];
  return JSON.stringify({
    semester: {
      remoteTermKey: academicYear + '-' + term,
      academicYear: academicYear,
      term: term,
      label: academicYear + ' 第' + term + '学期',
      totalWeeks: totalWeeks,
    },
    totalWeeks: totalWeeks,
    courses: courses,
  });
})()''';
