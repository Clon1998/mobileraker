/*
 * Copyright (c) 2024-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'sort_kind_enum.dart';

/// Represents the mode of sorting with associated translation keys.
enum SortMode {
  name('pages.files.sort_by.name', SortKind.ascending),
  lastModified('pages.files.sort_by.last_modified', SortKind.descending),
  lastPrinted('pages.files.sort_by.last_printed', SortKind.descending),
  estimatedPrintTime('pages.files.sort_by.estimated_time', SortKind.descending),
  size('pages.files.sort_by.file_size', SortKind.ascending),
  // Only for the print history, appended as the index of a mode is persisted.
  startTime('pages.history.sort_by.date', SortKind.descending),
  printDuration('pages.history.sort_by.print_duration', SortKind.descending),
  filamentUsed('pages.history.sort_by.filament_used', SortKind.descending),
  // Only for the Spoolman spools, appended as the index of a mode is persisted.
  spoolId('pages.spoolman.properties.id', SortKind.ascending),
  spoolLastUsed('pages.spoolman.properties.last_used', SortKind.descending),
  spoolRemainingWeight('pages.spoolman.properties.remaining_weight', SortKind.ascending),
  spoolRegistered('pages.spoolman.properties.registered', SortKind.descending),
  spoolLocation('pages.spoolman.properties.location', SortKind.ascending),
  spoolCount('pages.spoolman.sort_by.spool_count', SortKind.descending);

  const SortMode(this.translation, this.defaultKind);

  final String translation;

  final SortKind defaultKind;

  static List<SortMode> availableForGCodes() =>
      [
        name,
        lastModified,
        lastPrinted,
        estimatedPrintTime,
        size,
      ];

  static List<SortMode> availableForHistory() => [startTime, name, printDuration, filamentUsed];

  /// The flat list of Spoolman spools, [name] is the vendor and filament name.
  static List<SortMode> availableForSpools() =>
      [spoolId, name, spoolLastUsed, spoolRemainingWeight, spoolRegistered, spoolLocation];

  /// The Spoolman spools grouped (by filament, location, ...), [name] is the group's title.
  static List<SortMode> availableForSpoolGroups() => [name, spoolLastUsed, spoolRemainingWeight, spoolCount];

  static List<SortMode> availableForFiles() =>
      [
        name,
        lastModified,
        size,
      ];
}
