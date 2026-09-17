class CalendarCatalogEntry {
  const CalendarCatalogEntry(
      {required this.id, required this.asset, this.label});

  final String id;
  final String asset;
  final String? label;
}

class CalendarCatalog {
  CalendarCatalog._(this.entries);

  final List<CalendarCatalogEntry> entries;

  factory CalendarCatalog.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != null && json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported calendar catalog schemaVersion');
    }
    if (json['school'] != 'NWU') {
      throw const FormatException('Calendar catalog school must be NWU');
    }
    final raw = json['calendars'];
    if (raw is! List || raw.isEmpty) {
      throw const FormatException('Calendar catalog is empty');
    }
    final ids = <String>{};
    final assets = <String>{};
    final entries = <CalendarCatalogEntry>[];
    for (final item in raw) {
      if (item is! Map) {
        throw const FormatException('Invalid calendar catalog entry');
      }
      final id = item['id'];
      final asset = item['asset'];
      final label = item['label'];
      if (id is! String || id.trim().isEmpty || !ids.add(id)) {
        throw FormatException('Invalid or duplicate calendar id: $id');
      }
      if (asset is! String ||
          !RegExp(r'^[a-zA-Z0-9_-]+\.json$').hasMatch(asset) ||
          !assets.add(asset)) {
        throw FormatException('Invalid or duplicate calendar asset: $asset');
      }
      if (label != null && (label is! String || label.trim().isEmpty)) {
        throw const FormatException('Invalid calendar label');
      }
      entries.add(
          CalendarCatalogEntry(id: id, asset: asset, label: label as String?));
    }
    return CalendarCatalog._(List.unmodifiable(entries));
  }

  CalendarCatalogEntry? findById(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }
}
