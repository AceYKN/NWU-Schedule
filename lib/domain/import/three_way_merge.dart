enum MergeDecision { local, remote, conflict }

/// Resolves one imported field against the previous import and local edit.
/// A conflict retains the local value until the user explicitly chooses.
class MergeFieldResult<T> {
  const MergeFieldResult({
    required this.value,
    required this.decision,
    required this.localValue,
    required this.remoteValue,
  });

  final T value;
  final MergeDecision decision;
  final T localValue;
  final T remoteValue;

  bool get hasConflict => decision == MergeDecision.conflict;

  T resolveConflict({required bool useRemote}) {
    if (!hasConflict) return value;
    return useRemote ? remoteValue : localValue;
  }
}

MergeFieldResult<T> mergeField<T>({
  required T previousImport,
  required T local,
  required T incomingImport,
}) {
  if (local == incomingImport || incomingImport == previousImport) {
    return MergeFieldResult(
      value: local,
      decision: MergeDecision.local,
      localValue: local,
      remoteValue: incomingImport,
    );
  }
  if (local == previousImport) {
    return MergeFieldResult(
      value: incomingImport,
      decision: MergeDecision.remote,
      localValue: local,
      remoteValue: incomingImport,
    );
  }
  return MergeFieldResult(
    value: local,
    decision: MergeDecision.conflict,
    localValue: local,
    remoteValue: incomingImport,
  );
}
