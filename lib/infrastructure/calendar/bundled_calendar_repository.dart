import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/calendar/calendar_definition.dart';
import '../../domain/calendar/calendar_catalog.dart';

class BundledCalendarRepository {
  const BundledCalendarRepository({AssetBundle? bundle}) : _bundle = bundle;

  final AssetBundle? _bundle;

  Future<List<CalendarCatalogEntry>> listCalendars() async {
    final bundle = _bundle ?? rootBundle;
    final raw =
        await bundle.loadString('assets/calendars/nwu/source/index.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return CalendarCatalog.fromJson(json).entries;
  }

  Future<CalendarDefinition?> findById(String id) async {
    final entries = await listCalendars();
    final matches = entries.where((entry) => entry.id == id);
    if (matches.isEmpty) return null;
    final bundle = _bundle ?? rootBundle;
    final raw = await bundle.loadString(
      'assets/calendars/nwu/source/${matches.single.asset}',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final definition = CalendarDefinition.fromJson(json);
    if (definition.id != id) {
      throw FormatException('Calendar id mismatch for ${matches.single.asset}');
    }
    return definition;
  }
}
