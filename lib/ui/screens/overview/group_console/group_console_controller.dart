/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/console/gcode_store_entry.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/util/extensions/uri_extension.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_console_controller.freezed.dart';
part 'group_console_controller.g.dart';

@freezed
sealed class TaggedConsoleEntry with _$TaggedConsoleEntry {
  const factory TaggedConsoleEntry({required String machineUUID, required GCodeStoreEntry entry}) =
      _TaggedConsoleEntry;
}

// Disconnected from the single-machine console's settings (common/lib/service/setting_service.dart
// AppSettingKeys.reverseConsole / consoleShowTimestamp / filterTemperatureResponse) via CompositeKey,
// so toggling display prefs in one console view never affects the other.
final groupConsoleReverseKey = CompositeKey.keyWithString(AppSettingKeys.reverseConsole, 'group');
final groupConsoleShowTimestampKey = CompositeKey.keyWithString(AppSettingKeys.consoleShowTimestamp, 'group');
final groupConsoleFilterTemperatureKey = CompositeKey.keyWithString(AppSettingKeys.filterTemperatureResponse, 'group');

enum GroupConsoleIndicatorMode {
  machineName(
    'pages.overview.group_console.settings.indicator_name',
    'pages.overview.group_console.settings.indicator_name_desc',
  ),
  ipFull(
    'pages.overview.group_console.settings.indicator_ip_full',
    'pages.overview.group_console.settings.indicator_ip_full_desc',
  ),
  ipShort(
    'pages.overview.group_console.settings.indicator_ip_short',
    'pages.overview.group_console.settings.indicator_ip_short_desc',
  );

  const GroupConsoleIndicatorMode(this.labelTranslationKey, this.descriptionTranslationKey);

  final String labelTranslationKey;
  final String descriptionTranslationKey;

  String labelFor(Machine machine) => switch (this) {
        GroupConsoleIndicatorMode.machineName => machine.name,
        GroupConsoleIndicatorMode.ipFull => machine.httpUri.displayHost,
        GroupConsoleIndicatorMode.ipShort => _shortHost(machine.httpUri.displayHost),
      };
}

/// Last group of the address: `192.168.1.42` -> `42`, `2001:db8::1a2b` -> `1a2b`.
String _shortHost(String host) {
  // IPv6 literals are the only hosts containing a colon, strip the zone ID of link-local addresses
  if (host.contains(':')) return host.split('%').first.split(':').last;
  return host.split('.').last;
}

@riverpod
List<TaggedConsoleEntry> groupConsoleEntries(Ref ref, List<String> machineUUIDs) {
  final merged = <TaggedConsoleEntry>[
    for (final uuid in machineUUIDs)
      if (ref.watch(printerGCodeStoreProvider(uuid)).value case final entries?)
        for (final entry in entries) TaggedConsoleEntry(machineUUID: uuid, entry: entry),
  ];
  merged.sort((a, b) => a.entry.time.compareTo(b.entry.time));
  return merged;
}
