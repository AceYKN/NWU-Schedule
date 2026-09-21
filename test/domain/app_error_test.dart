import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/domain/backup/schedule_backup.dart';
import 'package:nwu_schedule/domain/errors/app_error.dart';
import 'package:nwu_schedule/domain/import/timetable_importer.dart';

void main() {
  test('maps backup parser failures to a safe user message', () {
    final error = classifyNwuError(
      const BackupValidationException('JSONDecodeException: password=secret'),
    );

    expect(error.code, NwuErrorCode.backupInvalid);
    expect(error.userMessage, isNot(contains('secret')));
    expect(error.userMessage, contains('备份文件无效'));
  });

  test('maps import bridge failures without exposing parser details', () {
    final error = TimetableImportFailure(
      'FormatException: invalid payload',
      const ImportDiagnostic(
        adapterVersion: 'nwu-zhengfang-v9',
        parserStage: 'bridge-message',
        error: 'FormatException: invalid payload',
      ),
    );

    expect(importFailureUserMessage(error), contains('课表数据不完整'));
    expect(importFailureUserMessage(error), isNot(contains('FormatException')));
  });

  test('separates timetable context failures from authentication failures', () {
    const error = TimetableImportFailure(
      '当前页面尚未识别为课表页面',
      ImportDiagnostic(
        adapterVersion: 'nwu-zhengfang-v9',
        parserStage: 'timetable-context',
        currentUrlPath: '/jwglxt/xtgl/index_initMenu.html',
        error: 'bridge-disabled',
      ),
    );

    expect(
        classifyNwuError(error).code, NwuErrorCode.timetableContextUnavailable);
    expect(importFailureUserMessage(error), contains('无法识别为课表页面'));
    expect(importFailureUserMessage(error), isNot(contains('登录状态已经失效')));
  });

  test('maps database failures to a stable presentation message', () {
    final error = classifyNwuError(StateError('SQLiteException: locked'));

    expect(error.code, NwuErrorCode.databaseFailure);
    expect(nwuUserMessage(error, action: '保存失败'), '保存失败：本地数据暂时无法读取或保存，请重试。');
  });

  test('explains that a missing calendar blocks date-based schedules', () {
    final error = const CalendarMissingError();

    expect(
      error.userMessage,
      '课程数据已安全保存，但当前版本缺少该学期校历，因此暂时无法生成按日期计算的完整课表。更新到包含该校历的版本后即可正常使用。',
    );
  });
}
