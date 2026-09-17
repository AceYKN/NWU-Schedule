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

  test('maps database failures to a stable presentation message', () {
    final error = classifyNwuError(StateError('SQLiteException: locked'));

    expect(error.code, NwuErrorCode.databaseFailure);
    expect(nwuUserMessage(error, action: '保存失败'), '保存失败：本地数据暂时无法读取或保存，请重试。');
  });
}
