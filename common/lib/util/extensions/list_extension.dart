
/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
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

  /// Trims the list to the specified size. If the list length is greater than the specified size,
  /// it returns a sublist containing the last `size` elements. If the list length is less than or
  /// equal to the specified size, it returns the original list.
  ///
  /// Throws an [AssertionError] if the specified size is negative.
  ///
  /// Example:
  /// ```dart
  /// final list = [1, 2, 3, 4, 5];
  /// final trimmedList = list.shrinkToFit(3); // [3, 4, 5]
  /// ```
  ///
  /// @param size The maximum size of the list.
  /// @return A list containing the last `size` elements if the original list length is greater than `size`,
  ///         otherwise the original list.
  List<E> shrinkToFit(int size) {
    assert(size >= 0);
    if (length <= size) return this;
    return sublist(length - size);
  }
}
