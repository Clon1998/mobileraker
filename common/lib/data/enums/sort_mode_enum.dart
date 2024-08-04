/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'sort_kind_enum.dart';

/// Represents the mode of sorting with associated translation keys.
enum SortMode {
  name('pages.files.name', SortKind.ascending),
  lastModified('pages.files.last_mod', SortKind.descending),
  lastPrinted('pages.files.last_printed', SortKind.descending),
  size('pages.files.file_size', SortKind.ascending);

  const SortMode(this.translation, this.defaultKind);

  final String translation;

  final SortKind defaultKind;
}
