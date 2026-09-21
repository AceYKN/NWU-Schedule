import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/bootstrap.dart';
import '../../../core/nwu/constants.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/week_mask.dart';
import '../../../domain/import/import_diff.dart';
import '../../../domain/import/timetable_import.dart';
import '../../../domain/import/timetable_importer.dart';
import '../../../domain/import/three_way_merge.dart';
import '../../../domain/errors/app_error.dart';
import '../../../infrastructure/backup/backup_file_service.dart';
import '../../../infrastructure/import/nwu_dom_extractor.dart';
import '../../../infrastructure/import/nwu_zhengfang_v9_importer.dart';
import '../../../infrastructure/import/webview_diagnostics.dart';
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
  int _navigationGeneration = 0;
  Future<void> _bridgeTransition = Future<void>.value();
  String? _latestStartedUrl;
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
            _latestStartedUrl = url;
            _navigationGeneration++;
            _queueBridgeDisable();
            if (mounted) setState(() => _currentUrl = url);
          },
          onPageFinished: (url) => _onPageFinished(
            url,
            generation: _navigationGeneration,
          ),
          onWebResourceError: (error) {
            if (error.isForMainFrame == false) return;
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

  Future<void> _onPageFinished(
    String url, {
    required int generation,
  }) async {
    if (generation != _navigationGeneration || url != _latestStartedUrl) {
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !NwuZhengfangV9Importer.isAllowedUri(uri)) {
      await _disableBridge();
      return;
    }
    await _bridgeTransition;
    if (generation != _navigationGeneration || url != _latestStartedUrl) {
      return;
    }
    if (mounted) setState(() => _currentUrl = url);
    if (NwuZhengfangV9Importer.isLoginUri(uri) ||
        !NwuZhengfangV9Importer.isTrustedTimetableUri(uri) ||
        await _currentTimetableContext() != 'timetable') {
      if (generation != _navigationGeneration || url != _latestStartedUrl) {
        return;
      }
      await _disableBridge();
      return;
    }
    if (generation != _navigationGeneration || url != _latestStartedUrl) {
      return;
    }
    if (_bridgeEnabled || !mounted) return;
    final transition = _bridgeTransition.then<void>((_) async {
      if (generation != _navigationGeneration || !mounted) return;
      await _controller.addJavaScriptChannel(
        _bridgeName,
        onMessageReceived: (message) =>
            _handleBridgeMessage(message.message, generation: generation),
      );
      if (generation != _navigationGeneration || !mounted) {
        await _removeBridgeChannel();
        return;
      }
      _bridgeEnabled = true;
    });
    _bridgeTransition = transition;
    await transition;
  }

  Future<String> _currentTimetableContext() async {
    try {
      final value = await _controller.runJavaScriptReturningResult(
        NwuDomExtractor.contextScript,
      );
      return value.toString().replaceAll('"', '').trim().toLowerCase();
    } on Object {
      // A page that cannot be inspected is not a safe timetable context.
      return 'other';
    }
  }

  Future<bool> _ensureListTimetableReady() async {
    try {
      final prepared = await _controller.runJavaScriptReturningResult(
        NwuDomExtractor.prepareListViewScript,
      );
      final state =
          prepared.toString().replaceAll('"', '').trim().toLowerCase();
      if (state == 'ready') return true;
      if (state != 'switching') return false;

      for (var attempt = 0; attempt < 15; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final ready = await _controller.runJavaScriptReturningResult(
          NwuDomExtractor.listViewReadyScript,
        );
        if (ready.toString().replaceAll('"', '').trim().toLowerCase() ==
            'ready') {
          return true;
        }
      }
      return false;
    } on Object {
      return false;
    }
  }

  Future<void> _disableBridge() async {
    if (!_bridgeEnabled) return;
    _bridgeEnabled = false;
    await _removeBridgeChannel();
  }

  void _queueBridgeDisable() {
    _bridgeEnabled = false;
    _bridgeTransition = _bridgeTransition.then<void>((_) async {
      await _removeBridgeChannel();
    });
  }

  Future<void> _removeBridgeChannel() async {
    await _bestEffort(() => _controller.removeJavaScriptChannel(_bridgeName));
  }

  Future<Map<String, dynamic>> _readPayload() async {
    final currentUrl = await _controller.currentUrl() ?? _currentUrl;
    final uri = currentUrl == null ? null : Uri.tryParse(currentUrl);
    if (uri == null || !NwuZhengfangV9Importer.isTrustedTimetableUri(uri)) {
      throw TimetableImportFailure(
        '当前不是个人课表页面',
        ImportDiagnostic(
          adapterVersion: NwuZhengfangV9Importer.adapterVersion,
          parserStage: 'timetable-context',
          currentUrlPath: uri?.path,
        ),
      );
    }

    final context = await _currentTimetableContext();
    if (context == 'login') {
      throw TimetableImportFailure(
        '教务系统登录状态已经失效',
        ImportDiagnostic(
          adapterVersion: NwuZhengfangV9Importer.adapterVersion,
          parserStage: 'authentication',
          currentUrlPath: uri.path,
        ),
      );
    }
    if (context != 'timetable') {
      throw TimetableImportFailure(
        '当前页面尚未识别到课表结构',
        ImportDiagnostic(
          adapterVersion: NwuZhengfangV9Importer.adapterVersion,
          parserStage: 'timetable-context',
          currentUrlPath: uri.path,
        ),
      );
    }

    if (!await _ensureListTimetableReady()) {
      throw TimetableImportFailure(
        '个人课表已经打开，但列表视图尚未准备完成',
        ImportDiagnostic(
          adapterVersion: NwuZhengfangV9Importer.adapterVersion,
          parserStage: 'timetable-context',
          currentUrlPath: uri.path,
        ),
      );
    }

    final result = await _controller.runJavaScriptReturningResult(
      NwuDomExtractor.extractionScript,
    );
    final payload = _decodePayload(result);
    if (payload == null) {
      throw TimetableImportFailure(
        '当前版本暂时无法识别教务系统课表',
        ImportDiagnostic(
          adapterVersion: NwuZhengfangV9Importer.adapterVersion,
          parserStage: 'parser',
          currentUrlPath: uri.path,
        ),
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
    final generation = _navigationGeneration;
    final importer = NwuZhengfangV9Importer(readPayload: _readPayload);
    try {
      final semesters = await importer.getSemesters();
      final selected = await _selectRemoteSemester(semesters);
      if (selected == null) return;
      final timetable = await importer.importSemester(selected);
      if (generation != _navigationGeneration) return;
      final diff = await _buildDiff(timetable);
      if (!mounted || generation != _navigationGeneration) return;
      setState(() {
        _timetable = timetable;
        _diff = diff;
        _resolution = ImportConflictResolution.empty;
      });
    } on TimetableImportFailure catch (error) {
      if (generation != _navigationGeneration) return;
      _setFailure(
        importFailureUserMessage(error),
        await _enrichDiagnostic(error.diagnostic),
      );
    } on Object catch (error) {
      if (generation != _navigationGeneration) return;
      _setFailure(
        nwuUserMessage(error, action: '无法读取课表'),
        await _enrichDiagnostic(ImportDiagnostic(
          adapterVersion: NwuZhengfangV9Importer.adapterVersion,
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

  void _handleBridgeMessage(
    String message, {
    required int generation,
  }) {
    unawaited(_handleBridgeMessageAsync(message, generation: generation));
  }

  Future<void> _handleBridgeMessageAsync(
    String message, {
    required int generation,
  }) async {
    if (!_bridgeEnabled || generation != _navigationGeneration) return;
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
      if (mounted && _bridgeEnabled && generation == _navigationGeneration) {
        setState(() {
          _timetable = timetable;
          _diff = diff;
          _resolution = ImportConflictResolution.empty;
          _error = null;
          _diagnostic = null;
        });
      }
    } on Object catch (error) {
      if (generation != _navigationGeneration) return;
      final diagnostic = await _enrichDiagnostic(ImportDiagnostic(
        adapterVersion: NwuZhengfangV9Importer.adapterVersion,
        parserStage: 'bridge-message',
        currentUrlPath: _currentUrlPath,
        error: redactImportError(error),
      ));
      if (generation != _navigationGeneration) return;
      _setFailure(
        nwuUserMessage(error, action: '课表桥接数据无效'),
        diagnostic,
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
            adapterVersion: NwuZhengfangV9Importer.adapterVersion,
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
        adapterVersion: NwuZhengfangV9Importer.adapterVersion,
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
      webViewVersion: WebViewDiagnostics.versionFromUserAgent(userAgent),
      currentUrlPath: _currentUrlPath,
      httpStatus: diagnostic.httpStatus ?? _lastHttpStatus,
      selectors: diagnostic.selectors.isEmpty
          ? _payloadSelectors
          : diagnostic.selectors,
    );
  }

  String? get _currentUrlPath {
    final uri = _currentUrl == null ? null : Uri.tryParse(_currentUrl!);
    return uri?.path;
  }

  Future<void> _clearSession() async {
    await _disableBridge();
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
                  child: TimetableImportPreviewCard(
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

class TimetableImportPreviewCard extends StatelessWidget {
  const TimetableImportPreviewCard({
    super.key,
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
            if (timetable.issues.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '发现 ${timetable.issues.length} 条可能异常的数据，已保留可识别的课程。',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (final issue in timetable.issues.take(3))
                Text(
                  '· ${issue.message}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (timetable.issues.length > 3)
                Text(
                  '还有 ${timetable.issues.length - 3} 条异常…',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
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
                  (course) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${course.name} · ${course.meetings.length} 个安排',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        for (final meeting in course.meetings.take(2))
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 2),
                            child: Text(
                              _previewMeetingLabel(meeting),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        if (course.meetings.length > 2)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 2),
                            child: Text(
                              '还有 ${course.meetings.length - 2} 个安排…',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
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

String _previewMeetingLabel(ImportedMeeting meeting) {
  final location = [
    if (meeting.campus != null) meeting.campus!,
    if (meeting.room != null) meeting.room!,
  ].join(' · ');
  return [
    weekdayName(meeting.weekday),
    '第 ${meeting.startSection}-${meeting.endSection} 节',
    formatWeekMask(meeting.weekMask),
    if (location.isNotEmpty) location,
    if (meeting.teacher != null) meeting.teacher!,
  ].join(' · ');
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
      'meetings' => '上课安排',
      _ when field.startsWith('meeting:') =>
        '上课安排 · ${_meetingPropertyLabel(field)}',
      _ => field,
    };

String _meetingPropertyLabel(String field) {
  final separator = field.lastIndexOf(':');
  final property = separator < 0 ? field : field.substring(separator + 1);
  return switch (property) {
    'weekday' => '星期',
    'startSection' => '开始节次',
    'endSection' => '结束节次',
    'weekMask' => '周次',
    'teacher' => '教师',
    'campus' => '校区',
    'room' => '教室',
    _ => property,
  };
}

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
