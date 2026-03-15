/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

abstract class StampedEntity {
  StampedEntity(DateTime? created, this.lastModified)
      : created = created ?? DateTime.now();

  final DateTime created;
  final DateTime lastModified;
}
