import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/calendar/calendar_definition.dart';

class BundledCalendarRepository {
  const BundledCalendarRepository({AssetBundle? bundle}) : _bundle = bundle;

  final AssetBundle? _bundle;

  Future<CalendarDefinition> load(String fileName) async {
    final bundle = _bundle ?? rootBundle;
    final raw = await bundle.loadString('assets/calendars/nwu/$fileName');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return CalendarDefinition.fromJson(json);
  }
}
