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
  filamentUsed('pages.history.sort_by.filament_used', SortKind.descending);

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

  static List<SortMode> availableForFiles() =>
      [
        name,
        lastModified,
        size,
      ];
}
