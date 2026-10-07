/// Serializes platform writes and supersedes work that has not published yet.
///
/// An operation must check [isCurrent] after asynchronous reads and before a
/// platform write. A write already in flight finishes before the next one.
class LatestTaskQueue<T> {
  LatestTaskQueue(this._operation);

  final Future<void> Function(T value, bool Function() isCurrent) _operation;
  Future<void> _tail = Future<void>.value();
  int _generation = 0;
  bool _disposed = false;

  Future<void> schedule(T value) {
    if (_disposed) return Future<void>.value();
    final generation = ++_generation;
    bool isCurrent() => !_disposed && generation == _generation;
    final task = _tail.then((_) async {
      if (isCurrent()) await _operation(value, isCurrent);
    });
    // Keep the queue usable after an error, while returning it to the caller.
    _tail = task.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return task;
  }

  void dispose() {
    _disposed = true;
    _generation++;
  }
}
