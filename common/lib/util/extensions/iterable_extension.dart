/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

extension IterableExtension<E> on Iterable<E> {
  int get hashIterable {
    return Object.hashAll(this);
  }
}
