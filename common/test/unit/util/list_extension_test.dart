/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/extensions/list_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ListExtensions', () {
    group('firstOrNull', () {
      test('returns null for empty list', () {
        final list = <int>[];
        expect(list.firstOrNull, isNull);
      });

      test('returns first element for non-empty list', () {
        final list = [1, 2, 3];
        expect(list.firstOrNull, 1);
      });
    });

    group('unpackAndCast', () {
      test('returns empty list for empty list', () {
        final list = <List<int>>[];
        expect(list.unpackAndCast<int>(), isEmpty);
      });

      test('returns casted list for single element list', () {
        final list = [
          [1, 2, 3]
        ];
        expect(list.unpackAndCast<int>(), [1, 2, 3]);
      });

      test('throws exception for list with more than one element', () {
        final list = [
          [1, 2, 3],
          [4, 5, 6]
        ];
        expect(() => list.unpackAndCast<int>(), throwsA(isA<TypeError>()));
      }, skip: true);
    });

    group('shrinkToFit', () {
      test('returns same list if size is greater than or equal to list length', () {
        final list = [1, 2, 3];
        expect(list.shrinkToFit(3), list);
        expect(list.shrinkToFit(5), list);
      });

      test('returns sublist if size is less than list length', () {
        final list = [1, 2, 3, 4, 5];
        expect(list.shrinkToFit(3), [3, 4, 5]);
      });

      test('returns empty list if size is zero', () {
        final list = [1, 2, 3];
        expect(list.shrinkToFit(0), isEmpty);
      });

      test('throws assertion error if size is negative', () {
        final list = [1, 2, 3];
        expect(() => list.shrinkToFit(-1), throwsA(isA<AssertionError>()));
      });
    });
  });
}
