
/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

extension ListExtensions<E> on List<E> {
  E? get firstOrNull {
    if (isEmpty) return null;
    return first;
  }

  ///
  List<D> unpackAndCast<D>() {
    if (isEmpty) return [];
    // if (length > 1)
    //   throw MobilerakerException('To many elements. Expected none or a single element to unpack!');
    return (elementAt(0) as List<dynamic>).cast<D>();
  }
}
