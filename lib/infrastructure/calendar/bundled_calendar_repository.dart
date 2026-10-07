import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/calendar/calendar_definition.dart';
import '../../domain/calendar/calendar_catalog.dart';

class BundledCalendarRepository {
  const BundledCalendarRepository({AssetBundle? bundle}) : _bundle = bundle;
  final AssetBundle? _bundle;
  static final _caches = Expando<_CalendarCache>();
  _CalendarCache get _cache =>
      _caches[_bundle ?? rootBundle] ??= _CalendarCache(_bundle ?? rootBundle);

  Future<List<CalendarCatalogEntry>> listCalendars() => _cache.catalog();
  Future<CalendarDefinition?> findById(String id) => _cache.definition(id);
}

class _CalendarCache {
  _CalendarCache(this.bundle);
  final AssetBundle bundle;
  Future<List<CalendarCatalogEntry>>? _catalog;
  final _definitions = <String, Future<CalendarDefinition?>>{};

  Future<List<CalendarCatalogEntry>> catalog() =>
      _catalog ??= _readCatalog().catchError((Object error) {
        _catalog = null; // Transient failures can be retried.
        throw error;
      });

  Future<List<CalendarCatalogEntry>> _readCatalog() async {
    final raw =
        await bundle.loadString('assets/calendars/nwu/source/index.json');
    return List.unmodifiable(
        CalendarCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>)
            .entries);
  }

  Future<CalendarDefinition?> definition(String id) => _definitions.putIfAbsent(
      id,
      () => _readDefinition(id).catchError((Object error) {
            _definitions.remove(id);
            throw error;
          }));

  Future<CalendarDefinition?> _readDefinition(String id) async {
    final matches = (await catalog()).where((entry) => entry.id == id);
    if (matches.isEmpty) return null;
    final raw = await bundle
        .loadString('assets/calendars/nwu/source/${matches.single.asset}');
    final definition =
        CalendarDefinition.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    if (definition.id != id) {
      throw FormatException('Calendar id mismatch for ${matches.single.asset}');
    }
    return definition;
  }
}
