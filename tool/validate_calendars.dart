import 'dart:convert';
import 'dart:io';

void main() {
  final root = Directory('assets/calendars/nwu');
  if (!root.existsSync()) {
    stderr.writeln('Calendar directory does not exist: ${root.path}');
    exitCode = 1;
    return;
  }

  final ids = <String>{};
  final files = root
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.json') && !file.path.endsWith('index.json'));
  for (final file in files) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final id = json['id'];
    if (id is! String || id.isEmpty || !ids.add(id)) {
      stderr.writeln('Invalid or duplicate calendar id in ${file.path}');
      exitCode = 1;
    }
    final term = (json['term'] as num?)?.toInt();
    final totalWeeks = (json['totalWeeks'] as num?)?.toInt();
    if (term == null || term < 1 || term > 3) {
      stderr.writeln('Invalid term in ${file.path}');
      exitCode = 1;
    }
    if (totalWeeks == null || totalWeeks < 1 || totalWeeks > 64) {
      stderr.writeln('Invalid totalWeeks in ${file.path}');
      exitCode = 1;
    }
    for (final key in [
      'semesterStartDate',
      'week1StartDate',
      'semesterEndDate',
    ]) {
      final value = json[key];
      if (value is! String || DateTime.tryParse(value) == null) {
        stderr.writeln('Invalid $key in ${file.path}');
        exitCode = 1;
      }
    }
  }
  if (exitCode == 0) {
    stdout.writeln('Calendar validation passed (${ids.length} file(s)).');
  }
}
