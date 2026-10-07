import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/core/utils/latest_task_queue.dart';

void main() {
  test('supersedes an old read before it can publish', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final writes = <String>[];
    final queue = LatestTaskQueue<String>((value, isCurrent) async {
      if (value == 'old') {
        started.complete();
        await release.future;
      }
      if (isCurrent()) writes.add(value);
    });
    final old = queue.schedule('old');
    await started.future;
    final newer = queue.schedule('new');
    release.complete();
    await Future.wait([old, newer]);
    expect(writes, ['new']);
  });

  test('finishes an in-flight write before publishing a clear', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final writes = <String>[];
    final queue = LatestTaskQueue<String>((value, _) async {
      writes.add('$value-start');
      if (value == 'plan') {
        started.complete();
        await release.future;
      }
      writes.add('$value-end');
    });
    final plan = queue.schedule('plan');
    await started.future;
    final clear = queue.schedule('clear');
    expect(writes, ['plan-start']);
    release.complete();
    await Future.wait([plan, clear]);
    expect(writes, ['plan-start', 'plan-end', 'clear-start', 'clear-end']);
  });

  test('coalesces pending changes and continues after a failed write',
      () async {
    final writes = <String>[];
    final queue = LatestTaskQueue<String>((value, _) async {
      if (value == 'fail') throw StateError('platform unavailable');
      writes.add(value);
    });
    await expectLater(queue.schedule('fail'), throwsStateError);
    await Future.wait([
      queue.schedule('intermediate'),
      queue.schedule('latest'),
    ]);
    expect(writes, ['latest']);
  });

  test('dispose prevents pending work from publishing', () async {
    final writes = <String>[];
    final queue =
        LatestTaskQueue<String>((value, _) async => writes.add(value));
    final task = queue.schedule('plan');
    queue.dispose();
    await task;
    await queue.schedule('later');
    expect(writes, isEmpty);
  });
}
