/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:common/util/form_number_parser.dart';

void main() {
  group('English', () {
    final parser = FormNumberParser('en');

    test('reads numbers with a dot', () {
      expect(parser.tryParse('19.99'), 19.99);
      expect(parser.tryParse(' 220 '), 220);
      expect(parser.tryParse('.5'), 0.5);
    });

    test('empty text is no number', () {
      expect(parser.tryParse(null), isNull);
      expect(parser.tryParse(''), isNull);
      expect(parser.tryParse('  '), isNull);
    });

    test('rejects a comma, grouping and special values', () {
      expect(parser.tryParse('19,99'), isNull);
      expect(parser.tryParse('1,000.5'), isNull);
      expect(parser.tryParse('NaN'), isNull);
      expect(parser.tryParse('Infinity'), isNull);
      expect(parser.tryParse('1e3'), isNull);
    });
  });

  group('German', () {
    final parser = FormNumberParser('de');

    test('reads the decimal comma and the dot', () {
      expect(parser.tryParse('19,99'), 19.99);
      expect(parser.tryParse('19.99'), 19.99);
      expect(parser.tryParse('196,5'), 196.5);
    });

    test('rejects text that is not a number', () {
      expect(parser.tryParse('1,2,3'), isNull);
      expect(parser.tryParse('abc'), isNull);
    });
  });
}
