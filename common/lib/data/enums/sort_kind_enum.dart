/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:json_annotation/json_annotation.dart';

/// Represents the direction of sorting.
enum SortKind {
  @JsonValue('asc')
  ascending,
  @JsonValue('desc')
  descending,
}
