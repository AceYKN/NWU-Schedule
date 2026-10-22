import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/bootstrap.dart';
import '../../../app/navigation.dart';
import '../../../core/nwu/constants.dart';
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
import 'import_exception_impacts.dart';
import 'timetable_import_instructions.dart';
import 'package:nwu_schedule/features/shared/presentation/campus_text.dart';

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
  bool _importStarted = false;

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
      );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_beginImport());
    });
  }

  Future<void> _beginImport() async {
    final start = await showTimetableImportInstructions(context, initial: true);
    if (!mounted) return;
    if (start != true) {
      popOrGo(context, '/');
      return;
    }
    setState(() => _importStarted = true);
    try {
      // A force-stop can bypass dispose(), leaving persisted WebView cookies.
      // Clear them again before every new import session, after any pending
      // cleanup, so restarting the process cannot reuse an authenticated page.
      await WebViewSessionService.serializeCleanup(
        const WebViewSessionService().clear,
      );
      if (mounted) {
        await _controller.loadRequest(NwuZhengfangV9Importer.entryUri);
      }
    } on Object {
      if (mounted) _setError('打开教务页面失败');
    }
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
    if (!mounted ||
        generation != _navigationGeneration ||
        url != _latestStartedUrl) {
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !NwuZhengfangV9Importer.isAllowedUri(uri)) {
      await _disableBridge();
      return;
    }
    await _bridgeTransition;
    if (!mounted ||
        generation != _navigationGeneration ||
        url != _latestStartedUrl) {
      return;
    }
    if (mounted) setState(() => _currentUrl = url);
    if (NwuZhengfangV9Importer.isLoginUri(uri) ||
        !NwuZhengfangV9Importer.isTrustedTimetableUri(uri) ||
        await _currentTimetableContext() != 'timetable') {
      if (!mounted ||
          generation != _navigationGeneration ||
          url != _latestStartedUrl) {
        return;
      }
      await _disableBridge();
      return;
    }
    if (!mounted ||
        generation != _navigationGeneration ||
        url != _latestStartedUrl) {
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

    if (uri != null && NwuZhengfangV9Importer.isLoginUri(uri)) {
      throw TimetableImportFailure(
        '当前会话已回到教务系统登录页面',
        ImportDiagnostic(
          adapterVersion: NwuZhengfangV9Importer.adapterVersion,
          parserStage: 'authentication',
          currentUrlPath: uri.path,
          error: 'login-page',
        ),
      );
    }
    if (uri == null || !NwuZhengfangV9Importer.isTrustedTimetableUri(uri)) {
      throw TimetableImportFailure(
        '当前页面尚未识别为课表页面',
        ImportDiagnostic(
          adapterVersion: NwuZhengfangV9Importer.adapterVersion,
          parserStage: 'timetable-context',
          currentUrlPath: uri?.path,
          error: 'untrusted-timetable-path',
        ),
      );
    }

    final context = await _currentTimetableContext();
    if (context == 'login') {
      throw TimetableImportFailure(
        '当前会话已回到教务系统登录页面',
        ImportDiagnostic(
          adapterVersion: NwuZhengfangV9Importer.adapterVersion,
          parserStage: 'authentication',
          currentUrlPath: uri.path,
          error: 'login-dom',
        ),
      );
    }
    if (context != 'timetable') {
      throw TimetableImportFailure(
        '当前页面尚未识别为课表页面',
        ImportDiagnostic(
          adapterVersion: NwuZhengfangV9Importer.adapterVersion,
          parserStage: 'timetable-context',
          currentUrlPath: uri.path,
          error: 'timetable-dom-missing',
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
          error: 'list-view-not-ready',
        ),
      );
    }

    final result = await _controller.runJavaScriptReturningResult(
      NwuDomExtractor.extractionScript,
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
    final generation = _navigationGeneration;
    final importer = NwuZhengfangV9Importer(readPayload: _readPayload);
    try {
      final semesters = await importer.getSemesters();
      final selected = await _selectRemoteSemester(semesters);
      if (selected == null) return;
      final timetable = await importer.importSemester(selected);
      if (!mounted || generation != _navigationGeneration) return;
      final diff = await _buildDiff(timetable);
      if (!mounted || generation != _navigationGeneration) return;
      setState(() {
        _timetable = timetable;
        _diff = diff;
        _resolution = ImportConflictResolution.empty;
      });
    } on TimetableImportFailure catch (error) {
      if (!mounted || generation != _navigationGeneration) return;
      final message = campusText(context, importFailureUserMessage(error));
      _setFailure(
        message,
        await _enrichDiagnostic(error.diagnostic),
      );
    } on Object catch (error) {
      if (!mounted || generation != _navigationGeneration) return;
      final message = campusUserMessage(context, error,
          action: campusText(context, '无法读取课表'));
      _setFailure(
        message,
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
            ListTile(
              title: Text(campusText(sheetContext, '选择要导入的学期')),
              subtitle: Text(campusText(sheetContext, '课表读取完成后才会写入本地数据')),
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
      if (!mounted || generation != _navigationGeneration) return;
      final diagnostic = await _enrichDiagnostic(ImportDiagnostic(
        adapterVersion: NwuZhengfangV9Importer.adapterVersion,
        parserStage: 'bridge-message',
        currentUrlPath: _currentUrlPath,
        error: redactImportError(error),
      ));
      if (!mounted || generation != _navigationGeneration) return;
      _setFailure(
        campusUserMessage(context, error,
            action: campusText(context, '课表桥接数据无效')),
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
      final impacts = diff.exceptionImpacts;
      final confirmed = await confirmImportExceptionImpacts(context, impacts);
      if (!confirmed || !mounted) return;
      await ref.read(scheduleDataRepositoryProvider).commitImportedTimetable(
        timetable,
        adapterVersion: NwuZhengfangV9Importer.adapterVersion,
        resolution: _resolution,
        expectedPreviewRevision: diff.previewRevision,
        removeExceptionIds: {
          for (final impact in impacts)
            if (impact.removed) impact.exception.id
        },
      );
      ref.invalidate(scheduleLoadProvider);
      if (mounted) context.go('/');
    } on ImportPreviewExpiredException {
      try {
        final refreshed = await _buildDiff(timetable);
        if (mounted) {
          setState(() {
            _diff = refreshed;
            _resolution = ImportConflictResolution.empty;
            _error = campusText(context, '本地课表已变化，预览已更新。请重新检查后确认导入。');
          });
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _diff = null;
            _error = campusUserMessage(context, error,
                action: campusText(context, '更新预览失败，请重新读取'));
          });
        }
      }
    } on ImportExceptionRemovalConfirmationRequired {
      _setError('受影响的临时变更已变化，请重新读取课表并确认。');
    } on TimetableImportConflictException {
      _setError('发现本地与教务系统同时修改的课程，导入已取消，未写入部分数据');
    } on Object catch (error) {
      if (!mounted) return;
      _setError(campusUserMessage(context, error,
          action: campusText(context, '确认导入失败')));
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
      if (mounted) {
        _showMessage(campusUserMessage(context, error,
            action: campusText(context, '诊断导出失败')));
      }
    }
  }

  void _setError(String message) {
    if (mounted) {
      final localized = campusText(context, message);
      setState(() => _error = localized);
    }
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
      _error = campusText(context, message);
      _diagnostic = diagnostic;
      _timetable = null;
      _diff = null;
      _resolution = ImportConflictResolution.empty;
    });
  }

  Future<void> _showConflictResolution() async {
    if (_saving || _reading) return;
    final diff = _diff;
    if (diff == null || (!diff.hasConflicts && !diff.hasLocallyDeleted)) {
      return;
    }
    final resolution = await showModalBottomSheet<ImportConflictResolution>(
      context: context,
      isScrollControlled: true,
      builder: (context) => TimetableImportConflictResolutionSheet(
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
    final url = _currentUrl ?? _latestStartedUrl;
    final uri = url == null ? null : Uri.tryParse(url);
    return uri?.path;
  }

  Future<void> _clearSession() =>
      WebViewSessionService.serializeCleanup(_clearOwnSession);

  Future<void> _clearOwnSession() async {
    await _bestEffort(_disableBridge);
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
                tooltip: campusText(context, '取消'),
                onPressed: () => popOrGo(context, '/'),
                icon: const Icon(Icons.close),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campusText(context, '从教务系统导入'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    TextButton.icon(
                      onPressed: () => showTimetableImportInstructions(context),
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: Text(campusText(context, '操作说明')),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed:
                    !_importStarted || _reading ? null : _readCurrentPage,
                icon: _reading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: Text(campusText(context, '读取课表')),
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
                  child: Text(campusText(context, '导出诊断')),
                ),
              TextButton(
                onPressed: () => setState(() => _error = null),
                child: Text(campusText(context, '关闭')),
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
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * .65),
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
    final dataIssues = timetable.issues
        .where((issue) => issue.path != 'courses.selfStudy')
        .toList(growable: false);
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text(
                        campusText(context, '读取完成 · {0}',
                            values: {'0': timetable.semester.label}),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(campusText(context, '{0} 门课程 · {1} 个上课安排', values: {
                        '0': timetable.courses.length,
                        '1': meetingCount
                      })),
                      if (timetable.ignoredSelfStudyCourseCount > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          campusText(context, '已忽略 {0} 门标记为自修的课程', values: {
                            '0': timetable.ignoredSelfStudyCourseCount
                          }),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                      if (dataIssues.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          campusText(context, '发现 {0} 条可能异常的数据，已保留可识别的课程。',
                              values: {'0': dataIssues.length}),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        for (final issue in dataIssues.take(3))
                          Text(
                            '· ${issue.message}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (dataIssues.length > 3)
                          Text(
                            campusText(context, '还有 {0} 条异常…',
                                values: {'0': dataIssues.length - 3}),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                      if (diff != null) ...[
                        const SizedBox(height: 4),
                        if (diff!.exceptionImpacts.isNotEmpty) ...[
                          Text(
                              campusText(context, '影响 {0} 条临时变更',
                                  values: {'0': diff!.exceptionImpacts.length}),
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w700)),
                          Text(importExceptionImpactSummary(
                              diff!.exceptionImpacts)),
                          const SizedBox(height: 8),
                        ],
                        if (diff!.isNewSemester)
                          Text(
                            campusText(
                                context, '发现新的学期，确认后会建立独立的本地课表，不会覆盖其他学期。'),
                          ),
                        Text(
                          campusText(context,
                              '新增 {0} · 更新 {1} · 删除 {2} · 本地删除 {3} · 冲突 {4}',
                              values: {
                                '0': diff!.addedCount,
                                '1': diff!.modifiedCount,
                                '2': diff!.removedCount,
                                '3': diff!.locallyDeletedCount,
                                '4': diff!.conflictCount
                              }),
                          style: TextStyle(
                            color: diff!.hasConflicts
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                        ),
                        if (diff!.hasConflicts)
                          Text(
                            campusText(context, '检测到本地与远端同时修改，请先解决冲突后再确认导入。'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        TextButton.icon(
                            onPressed: () => showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                showDragHandle: true,
                                builder: (_) => _ImportChangesSheet(
                                    diff: diff!, timetable: timetable)),
                            icon: const Icon(Icons.compare_arrows),
                            label: Text(campusText(context, '查看完整变化清单'))),
                        if (hasConflictItems)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: saving ? null : onResolveConflicts,
                              icon: const Icon(Icons.merge_type),
                              label: Text(
                                diff!.hasConflicts
                                    ? campusText(context, '解决冲突')
                                    : campusText(context, '处理本地删除课程'),
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
                                    campusText(context, '{0} · {1} 个安排',
                                        values: {
                                          '0': course.name,
                                          '1': course.meetings.length
                                        }),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                  for (final meeting in course.meetings.take(2))
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 8, top: 2),
                                      child: Text(
                                        _previewMeetingLabel(context, meeting),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                  if (course.meetings.length > 2)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 8, top: 2),
                                      child: Text(
                                        campusText(context, '还有 {0} 个安排…',
                                            values: {
                                              '0': course.meetings.length - 2
                                            }),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      if (timetable.courses.length > 3)
                        Text(campusText(context, '还有 {0} 门课程…',
                            values: {'0': timetable.courses.length - 3})),
                    ]))),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                    onPressed: saving ? null : onCancel,
                    child: Text(campusText(context, '取消'))),
                TextButton(
                    onPressed: saving ? null : onRetry,
                    child: Text(campusText(context, '重新读取'))),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed:
                      saving || diff == null || diff?.hasConflicts == true
                          ? null
                          : onConfirm,
                  child: Text(
                    saving
                        ? campusText(context, '导入中…')
                        : diff?.isNewSemester == true
                            ? campusText(context, '建立新课表')
                            : campusText(context, '确认导入'),
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

String _previewMeetingLabel(BuildContext context, ImportedMeeting meeting) {
  final location = [
    if (meeting.campus != null) meeting.campus!,
    if (meeting.room != null) meeting.room!,
  ].join(' · ');
  return [
    campusWeekdayName(context, meeting.weekday),
    campusText(context, '第 {0}-{1} 节',
        values: {'0': meeting.startSection, '1': meeting.endSection}),
    campusWeekMask(context, meeting.weekMask),
    if (location.isNotEmpty) location,
    if (meeting.teacher != null) meeting.teacher!,
  ].join(' · ');
}

class _ImportChangesSheet extends StatelessWidget {
  const _ImportChangesSheet({required this.diff, required this.timetable});
  final ImportDiff diff;
  final RemoteTimetable timetable;

  @override
  Widget build(BuildContext context) {
    final changed = diff.changes
        .where((c) => c.kind != ImportChangeKind.unchanged)
        .toList();
    return SafeArea(
        child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .8,
            child: Column(children: [
              ListTile(
                  title: Text(campusText(context, '完整变化清单')),
                  subtitle: Text(campusText(context, '确认导入前可逐项核对；此页面不会保存课程'))),
              Expanded(
                  child: ListView(children: [
                if (changed.isEmpty)
                  ListTile(title: Text(campusText(context, '没有变化'))),
                for (final change in changed)
                  ExpansionTile(
                      initiallyExpanded: true,
                      title: Text(
                          '${campusText(context, _changeLabel(change.kind))} · ${change.remoteCourse?.name ?? change.localCourse?.name ?? change.sourceCourseKey}'),
                      children: [
                        for (final field in change.fields.where((f) =>
                            jsonEncode(f.localValue) !=
                            jsonEncode(f.remoteValue)))
                          ListTile(
                              title: Text(_changeFieldLabel(
                                  context, change, field.field)),
                              subtitle: Text(
                                  campusText(context, '{0} → {1}{2}', values: {
                                '0': _displayValue(
                                    context, field.localValue, field.field),
                                '1': _displayValue(
                                    context, field.remoteValue, field.field),
                                '2': field.decision == MergeDecision.local
                                    ? campusText(context, '（保留本地）')
                                    : field.hasConflict
                                        ? campusText(context, '（待解决）')
                                        : ''
                              }))),
                        if (change.kind == ImportChangeKind.added &&
                            change.remoteCourse != null)
                          for (final meeting in change.remoteCourse!.meetings)
                            ListTile(
                                title: Text(
                                    _previewMeetingLabel(context, meeting))),
                        if (change.kind == ImportChangeKind.removed)
                          ListTile(
                              title: Text(
                                  campusText(context, '远端已移除此课程，确认后将从有效课表移除'))),
                      ]),
                ExpansionTile(
                    title: Text(campusText(context, '全部课程（{0}）',
                        values: {'0': timetable.courses.length})),
                    children: [
                      for (final course in timetable.courses)
                        ListTile(
                            title: Text(course.name),
                            subtitle: Text(course.meetings
                                .map((meeting) =>
                                    _previewMeetingLabel(context, meeting))
                                .join('\n'))),
                    ]),
              ])),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(campusText(context, '返回核对'))),
            ])));
  }
}

String _changeFieldLabel(
    BuildContext context, ImportChange change, String field) {
  if (!field.startsWith('meeting:')) return _fieldLabel(context, field);
  final key = field.substring(8, field.lastIndexOf(':'));
  final matches =
      change.remoteCourse?.meetings.where((m) => m.sourceMeetingKey == key);
  if (matches == null || matches.isEmpty) return _fieldLabel(context, field);
  final meeting = matches.first;
  return '${campusWeekdayName(context, meeting.weekday)} · ${campusText(context, '第{0}-{1}节', values: {
        '0': meeting.startSection,
        '1': meeting.endSection
      })} · ${_meetingPropertyLabel(context, field)}';
}

String _changeLabel(ImportChangeKind kind) => switch (kind) {
      ImportChangeKind.added => '新增',
      ImportChangeKind.removed => '删除',
      ImportChangeKind.modified => '修改',
      ImportChangeKind.conflict => '冲突',
      ImportChangeKind.locallyDeleted => '本地已删除',
      ImportChangeKind.unchanged => '未变化',
    };

class _ConflictEntry {
  const _ConflictEntry(this.change, this.field);

  final ImportChange change;
  final ImportFieldChange field;
}

class TimetableImportConflictResolutionSheet extends StatefulWidget {
  const TimetableImportConflictResolutionSheet({
    super.key,
    required this.diff,
    required this.initial,
  });

  final ImportDiff diff;
  final ImportConflictResolution initial;

  @override
  State<TimetableImportConflictResolutionSheet> createState() =>
      _ConflictResolutionSheetState();
}

class _ConflictResolutionSheetState
    extends State<TimetableImportConflictResolutionSheet> {
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
                campusText(context, '处理导入变更'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(campusText(context, '本地删除默认保留；冲突字段和恢复动作都由你明确选择。')),
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
                          title: Text(campusText(context, '恢复 {0}',
                              values: {'0': courseName})),
                          subtitle: Text(
                              campusText(context, '教务系统中仍存在这门课程，勾选后本次导入会恢复它。')),
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
                                '${entry.change.remoteCourse?.name ?? entry.change.sourceCourseKey} · ${_fieldLabel(context, entry.field.field)}',
                              ),
                              subtitle: Text(
                                campusText(context, '本地：{0}\n教务：{1}', values: {
                                  '0': _displayValue(
                                      context,
                                      entry.field.localValue,
                                      entry.field.field),
                                  '1': _displayValue(
                                      context,
                                      entry.field.remoteValue,
                                      entry.field.field)
                                }),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: SegmentedButton<MergeDecision>(
                                emptySelectionAllowed: selected == null,
                                segments: [
                                  ButtonSegment(
                                    value: MergeDecision.local,
                                    label: Text(campusText(context, '保留本地')),
                                  ),
                                  ButtonSegment(
                                    value: MergeDecision.remote,
                                    label: Text(campusText(context, '采用教务')),
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
                  child: Text(_complete
                      ? campusText(context, '应用选择')
                      : campusText(context, '请完成全部选择')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _fieldLabel(BuildContext context, String field) => switch (field) {
      'name' => campusText(context, '课程名'),
      'meetings' => campusText(context, '上课安排'),
      _ when field.startsWith('meeting:') =>
        '${campusText(context, '上课安排')} · ${_meetingPropertyLabel(context, field)}',
      _ => field,
    };

String _meetingPropertyLabel(BuildContext context, String field) {
  final separator = field.lastIndexOf(':');
  final property = separator < 0 ? field : field.substring(separator + 1);
  return switch (property) {
    'weekday' => campusText(context, '星期'),
    'startSection' => campusText(context, '开始节次'),
    'endSection' => campusText(context, '结束节次'),
    'weekMask' => campusText(context, '周次'),
    'teacher' => campusText(context, '教师'),
    'campus' => campusText(context, '校区'),
    'room' => campusText(context, '教室'),
    _ => property,
  };
}

String _displayValue(BuildContext context, Object? value, String field) {
  if (value == null) return campusText(context, '未填写');
  if (field == 'meetings' && value is List) {
    return value.map((item) {
      if (item is! List || item.length < 4) return item.toString();
      return '${campusWeekdayName(context, item[0] as int)} · ${campusText(context, '第 {0}-{1} 节', values: {
            '0': item[1],
            '1': item[2]
          })} · ${campusWeekMask(context, WeekMask(item[3] as int))}';
    }).join('\n');
  }
  if (field.endsWith(':weekday') && value is int) {
    return campusWeekdayName(context, value);
  }
  if (field.endsWith(':weekMask') && value is int) {
    return campusWeekMask(context, WeekMask(value));
  }
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
