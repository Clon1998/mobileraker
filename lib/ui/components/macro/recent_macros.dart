/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/console/gcode_store_entry.dart';
import 'package:common/data/enums/console_entry_type_enum.dart';
import 'package:common/data/model/moonraker_db/settings/gcode_macro.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// How many macros "Recent" shows.
const recentMacrosLimit = 8;

/// Lowercased names of the recently sent commands of a machine, newest first and without duplicates, joined by spaces
/// (a String so watchers only rebuild when the names change, not on every console line).
///
/// Built from Moonraker's G-code store, so it includes commands sent from other clients (Mainsail, Fluidd, the console)
/// but not those run by macros or G-code files.
final recentCommandNamesProvider = Provider.autoDispose.family<String, String>((ref, machineUUID) {
  return ref.watch(
    printerGCodeStoreProvider(machineUUID).select((store) => recentCommandNames(store.value ?? const []).join(' ')),
  );
});

/// See [recentCommandNamesProvider]. Batches (several lines sent at once) count every line.
List<String> recentCommandNames(List<GCodeStoreEntry> store, {int limit = 50}) {
  final names = <String>{};
  for (final entry in store.reversed) {
    if (entry.type != ConsoleEntryType.command && entry.type != ConsoleEntryType.batchCommand) continue;
    for (final line in entry.message.split('\n').reversed) {
      final name = line.trim().split(RegExp(r'\s+')).first.toLowerCase();
      if (name.isNotEmpty) names.add(name);
      if (names.length >= limit) return names.toList();
    }
  }
  return names.toList();
}

/// The [visible] macros (already filtered for visibility and print state) that were run recently, newest first.
List<GCodeMacro> recentMacros(String recentNames, List<GCodeMacro> visible, {int limit = recentMacrosLimit}) {
  if (recentNames.isEmpty) return const [];
  final byName = {for (final macro in visible) macro.configName: macro};
  return recentNames.split(' ').map((name) => byName[name]).nonNulls.take(limit).toList();
}
