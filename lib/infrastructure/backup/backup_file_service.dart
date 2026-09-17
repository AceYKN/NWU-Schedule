import 'package:flutter/services.dart';

class BackupFileService {
  const BackupFileService();

  static const _channel = MethodChannel('nwu_schedule/backup_files');

  Future<bool> save(String content) async {
    final saved = await _channel.invokeMethod<bool>(
      'saveBackup',
      <String, Object?>{
        'content': content,
        'suggestedName': 'nwu-schedule-backup.json',
      },
    );
    return saved ?? false;
  }

  Future<String?> pick() {
    return _channel.invokeMethod<String>('pickBackup');
  }
}
