import '../backup/schedule_backup.dart';
import '../import/timetable_import.dart';
import '../import/timetable_importer.dart';

enum NwuErrorCode {
  authenticationExpired,
  timetableContextUnavailable,
  timetableEndpointUnavailable,
  parserMismatch,
  invalidRemoteData,
  calendarMissing,
  databaseFailure,
  backupInvalid,
  notificationPermissionDenied,
  fileOperation,
  unknown,
}

sealed class NwuAppError implements Exception {
  const NwuAppError(this.code, this.userMessage);

  final NwuErrorCode code;
  final String userMessage;

  @override
  String toString() => userMessage;
}

final class AuthenticationExpiredError extends NwuAppError {
  const AuthenticationExpiredError()
      : super(
          NwuErrorCode.authenticationExpired,
          '登录状态已经失效，请重新登录西北大学教务系统。',
        );
}

final class TimetableContextUnavailableError extends NwuAppError {
  const TimetableContextUnavailableError()
      : super(
          NwuErrorCode.timetableContextUnavailable,
          '已经打开个人课表，但当前课表结构尚未准备完成，请等待页面加载后重试。',
        );
}

final class TimetableEndpointUnavailableError extends NwuAppError {
  const TimetableEndpointUnavailableError()
      : super(
          NwuErrorCode.timetableEndpointUnavailable,
          '暂时无法连接西北大学教务系统，请检查网络后重试。',
        );
}

final class ParserMismatchError extends NwuAppError {
  const ParserMismatchError()
      : super(
          NwuErrorCode.parserMismatch,
          '当前版本暂时无法识别教务系统课表，页面可能已经发生变化。',
        );
}

final class InvalidRemoteDataError extends NwuAppError {
  const InvalidRemoteDataError()
      : super(
          NwuErrorCode.invalidRemoteData,
          '教务系统返回的课表数据不完整，请重新读取或导出诊断信息。',
        );
}

final class CalendarMissingError extends NwuAppError {
  const CalendarMissingError()
      : super(
          NwuErrorCode.calendarMissing,
          '课程数据已安全保存，但当前版本缺少该学期校历，因此暂时无法生成按日期计算的完整课表。更新到包含该校历的版本后即可正常使用。',
        );
}

final class DatabaseFailureError extends NwuAppError {
  const DatabaseFailureError()
      : super(
          NwuErrorCode.databaseFailure,
          '本地数据暂时无法读取或保存，请重试。',
        );
}

final class BackupInvalidError extends NwuAppError {
  const BackupInvalidError()
      : super(
          NwuErrorCode.backupInvalid,
          '备份文件无效或版本不受支持，请选择由本应用导出的备份。',
        );
}

final class NotificationPermissionDeniedError extends NwuAppError {
  const NotificationPermissionDeniedError()
      : super(
          NwuErrorCode.notificationPermissionDenied,
          '未获得通知权限，课程提醒未开启。你仍可以正常使用课表。',
        );
}

final class FileOperationError extends NwuAppError {
  const FileOperationError()
      : super(NwuErrorCode.fileOperation, '文件操作未完成，请重试。');
}

final class UnknownNwuError extends NwuAppError {
  const UnknownNwuError() : super(NwuErrorCode.unknown, '操作未完成，请重试。');
}

NwuAppError classifyNwuError(Object error) {
  if (error is NwuAppError) return error;
  if (error is BackupValidationException) {
    return const BackupInvalidError();
  }
  if (error is TimetableImportConflictException ||
      error is TimetableImportValidationException) {
    return const InvalidRemoteDataError();
  }
  if (error is TimetableImportFailure) {
    return _classifyImportFailure(error);
  }
  if (error is FormatException) {
    return const InvalidRemoteDataError();
  }

  final text = error.toString().toLowerCase();
  if (text.contains('401') ||
      text.contains('403') ||
      text.contains('login') ||
      text.contains('sso') ||
      text.contains('session') ||
      text.contains('cookie')) {
    return const AuthenticationExpiredError();
  }
  if (text.contains('sqlite') ||
      text.contains('drift') ||
      text.contains('database') ||
      text.contains('constraint')) {
    return const DatabaseFailureError();
  }
  if (text.contains('permission') && text.contains('notif')) {
    return const NotificationPermissionDeniedError();
  }
  if (text.contains('file') ||
      text.contains('document') ||
      text.contains('picker')) {
    return const FileOperationError();
  }
  if (text.contains('socket') ||
      text.contains('connection') ||
      text.contains('network') ||
      text.contains('timeout')) {
    return const TimetableEndpointUnavailableError();
  }
  return const UnknownNwuError();
}

NwuAppError _classifyImportFailure(TimetableImportFailure failure) {
  final stage = failure.diagnostic.parserStage.toLowerCase();
  final text = failure.message.toLowerCase();
  if (stage.contains('authentication')) {
    return const AuthenticationExpiredError();
  }
  if (stage.contains('timetable-context')) {
    return const TimetableContextUnavailableError();
  }
  if (stage.contains('validation') || stage.contains('bridge')) {
    return const InvalidRemoteDataError();
  }
  if (stage.contains('parser') ||
      stage.contains('timetable') ||
      stage.contains('semester')) {
    return const ParserMismatchError();
  }
  return const TimetableEndpointUnavailableError();
}

String nwuUserMessage(Object error, {String? action}) {
  final message = classifyNwuError(error).userMessage;
  return action == null ? message : '$action：$message';
}

String importFailureUserMessage(TimetableImportFailure failure) {
  return classifyNwuError(failure).userMessage;
}
