/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:common/util/extensions/object_extension.dart';

class PaginationResult<T> {
  PaginationResult(this.items, this.totalItems, this.page, this.pageSize);

  // Items of the current page
  final List<T> items;

  // Total amount of items -> implemnted to support pagination without count
  final int? totalItems;

  // Page is 0-based
  final int page;

  // Page size is the amount of items per page
  final int pageSize;

  bool get hasNextPage {
    if (items.length < pageSize) return false;
    if (totalItems == null) return true; // if totalItems is null, we assume there are more items if we have a full page
    return (page + 1) * pageSize < totalItems!;
  }

  bool get hasItems => items.isNotEmpty;

  bool get hasPreviousPage => page > 0;

  int? get totalPages => totalItems?.let((it) => (it / pageSize).ceil());

  int get nextPage => page + 1;

  int get previousPage => page - 1;

  int get remainingItems {
    if (items.length < pageSize) return 0;
    if (totalItems == null)
      return pageSize; // if totalItems is null, we assume there are more items if we have a full page
    return max(totalItems! - (page * pageSize), 0);
  }

  @override
  String toString() {
    return 'PaginationResult{items: $items, totalItems: $totalItems, page: $page, pageSize: $pageSize}';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PaginationResult &&
            const DeepCollectionEquality().equals(other.items, items) &&
            (identical(other.totalItems, totalItems) || other.totalItems == totalItems) &&
            (identical(other.page, page) || other.page == page) &&
            (identical(other.pageSize, pageSize) || other.pageSize == pageSize));
  }

  @override
  int get hashCode => Object.hash(runtimeType, totalItems, page, pageSize, const DeepCollectionEquality().hash(items));
}
