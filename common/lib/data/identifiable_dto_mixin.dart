/*
 * Copyright (c) 2024-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'serializable_to_json_mixin.dart';

/// Mixin to add an id to a DTO.
mixin IdentifiableMixin implements SerializableToJsonMixin {
  int get id;
}
