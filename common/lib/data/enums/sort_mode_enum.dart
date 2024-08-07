/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'sort_kind_enum.dart';

/// Represents the mode of sorting with associated translation keys.
enum SortMode {
  name('pages.files.sort_by.name', SortKind.ascending),
  lastModified('pages.files.sort_by.last_modified', SortKind.descending),
  lastPrinted('pages.files.sort_by.last_printed', SortKind.descending),
  size('pages.files.sort_by.file_size', SortKind.ascending);

  const SortMode(this.translation, this.defaultKind);

  final String translation;

  final SortKind defaultKind;
}
