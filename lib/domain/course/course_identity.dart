class CourseIdentity {
  const CourseIdentity._();

  static String nameKey(String name) => name
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();

  static bool sameName(String left, String right) =>
      nameKey(left) == nameKey(right);

  static String importSourceKey(String remoteTermKey, String name) {
    final identity = '$remoteTermKey|${nameKey(name)}';
    var hash = 0x811c9dc5;
    for (final codeUnit in identity.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 'nwu-v4|course|${hash.toRadixString(16).padLeft(8, '0')}';
  }
}
