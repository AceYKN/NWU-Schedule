import 'dart:io';

void main(List<String> args) {
  final manifest = File('pubspec.yaml').readAsStringSync();
  final version = RegExp(r'^version:\s*(\S+)', multiLine: true)
      .firstMatch(manifest)!
      .group(1)!;
  final content =
      '// Generated from pubspec.yaml by tool/generate_app_version.dart.\n'
      "const defaultAppVersion = '$version';\n";
  final target = File('lib/core/nwu/app_version.g.dart');
  if (args.contains('--check')) {
    if (!target.existsSync() || target.readAsStringSync() != content) {
      stderr.writeln(
          'App version is stale. Run dart run tool/generate_app_version.dart');
      exitCode = 1;
    }
  } else {
    target.writeAsStringSync(content);
  }
}
