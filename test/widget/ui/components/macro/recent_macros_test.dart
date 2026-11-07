/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/console/gcode_store_entry.dart';
import 'package:common/data/enums/console_entry_type_enum.dart';
import 'package:common/data/model/moonraker_db/settings/gcode_macro.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/ui/components/macro/recent_macros.dart';

void main() {
  GCodeStoreEntry response(String message) =>
      GCodeStoreEntry(message: message, type: ConsoleEntryType.response, time: 0);

  group('recentCommandNames', () {
    test('lists the command names newest first, lowercased and without params or duplicates', () {
      final store = [
        GCodeStoreEntry.command('PURGE_LINE'),
        response('ok'),
        GCodeStoreEntry.command('load_filament TEMP=240'),
        GCodeStoreEntry.command('PURGE_LINE'),
        response('// purge done'),
      ];

      expect(recentCommandNames(store), ['purge_line', 'load_filament']);
    });

    test('counts every line of a batch, the last line being the newest', () {
      final store = [GCodeStoreEntry.command('G28\nNOZZLE_WIPE\nPURGE_LINE')];

      expect(recentCommandNames(store), ['purge_line', 'nozzle_wipe', 'g28']);
    });

    test('stops at the limit', () {
      final store = [for (var i = 0; i < 10; i++) GCodeStoreEntry.command('M$i')];

      expect(recentCommandNames(store, limit: 3), ['m9', 'm8', 'm7']);
    });
  });

  group('recentMacros', () {
    final visible = [
      GCodeMacro(name: 'PURGE_LINE'),
      GCodeMacro(name: 'NOZZLE_WIPE'),
      GCodeMacro(name: 'LOAD_FILAMENT'),
    ];

    test('keeps the order of the names and skips non-macros and hidden macros', () {
      final recent = recentMacros('g28 nozzle_wipe hidden_macro purge_line', visible);

      expect([for (final m in recent) m.name], ['NOZZLE_WIPE', 'PURGE_LINE']);
    });

    test('is empty without names and capped at the limit', () {
      expect(recentMacros('', visible), isEmpty);
      expect(recentMacros('purge_line nozzle_wipe load_filament', visible, limit: 2), hasLength(2));
    });
  });
}
