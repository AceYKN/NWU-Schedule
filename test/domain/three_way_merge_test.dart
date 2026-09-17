import 'package:flutter_test/flutter_test.dart';
import 'package:nwu_schedule/domain/import/three_way_merge.dart';

void main() {
  test('remote-only change uses incoming value', () {
    final result = mergeField(
      previousImport: '3406',
      local: '3406',
      incomingImport: '3508',
    );
    expect(result.value, '3508');
    expect(result.decision, MergeDecision.remote);
  });

  test('local-only change retains local value', () {
    final result = mergeField(
      previousImport: '3406',
      local: '3508',
      incomingImport: '3406',
    );
    expect(result.value, '3508');
    expect(result.decision, MergeDecision.local);
  });

  test('same local and remote change has no conflict', () {
    final result = mergeField(
      previousImport: '3406',
      local: '3508',
      incomingImport: '3508',
    );
    expect(result.value, '3508');
    expect(result.hasConflict, isFalse);
  });

  test('divergent changes require explicit choice and default local', () {
    final result = mergeField(
      previousImport: '3406',
      local: '3508',
      incomingImport: '3201',
    );
    expect(result.hasConflict, isTrue);
    expect(result.value, '3508');
    expect(result.resolveConflict(useRemote: false), '3508');
    expect(result.resolveConflict(useRemote: true), '3201');
  });

  test('nullable fields can be removed by either side', () {
    final remoteRemoved = mergeField<String?>(
      previousImport: '3406',
      local: '3406',
      incomingImport: null,
    );
    expect(remoteRemoved.value, isNull);
    final localRemoved = mergeField<String?>(
      previousImport: '3406',
      local: null,
      incomingImport: '3406',
    );
    expect(localRemoved.value, isNull);
  });
}
