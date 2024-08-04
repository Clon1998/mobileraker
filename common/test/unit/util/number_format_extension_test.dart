/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/extensions/number_format_extension.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  final numberFormat = NumberFormat('#.##');

  group('Precision extension tests', () {
    test('formatGrams with grams', () {
      expect(numberFormat.formatGrams(999), '999 g');
    });

    test('formatGrams with kilograms', () {
      expect(numberFormat.formatGrams(1500), '1.5 kg');
    });

    test('formatGrams with tonnes', () {
      expect(numberFormat.formatGrams(1500000), '1.5 t');
    });

    test('formatMillimeters with micrometers', () {
      expect(numberFormat.formatMillimeters(0.5, useMicro: true), '500 µm');
    });

    test('formatMillimeters with small value and useMicro false', () {
      expect(numberFormat.formatMillimeters(0.5, useMicro: false), '0.5 mm');
    });

    test('formatMillimeters with millimeters', () {
      expect(numberFormat.formatMillimeters(999), '999 mm');
    });

    test('formatMillimeters with meters', () {
      expect(numberFormat.formatMillimeters(1500), '1.5 m');
    });

    test('formatMillimeters with kilometers', () {
      expect(numberFormat.formatMillimeters(1500000), '1.5 km');
    });

    test('formatFileSize with bits', () {
      expect(numberFormat.formatFileSize(999), '999 bits');
    });

    test('formatFileSize with kilobytes', () {
      expect(numberFormat.formatFileSize(1500), '1.46 kB');
    });

    test('formatFileSize with megabytes', () {
      expect(numberFormat.formatFileSize(1500000), '1.43 MB');
    });

    test('formatFileSize with gigabytes', () {
      expect(numberFormat.formatFileSize(1500000000), '1.4 GB');
    });

    test('formatFileSize with terabytes', () {
      expect(numberFormat.formatFileSize(1500000000000), '1.36 TB');
    });

    test('throws ArgumentError for negative weight', () {
      expect(() => numberFormat.formatGrams(-100), throwsArgumentError);
    });

    test('throws ArgumentError for negative length', () {
      expect(() => numberFormat.formatMillimeters(-100), throwsArgumentError);
    });

    test('throws ArgumentError for negative file size', () {
      expect(() => numberFormat.formatFileSize(-100), throwsArgumentError);
    });

    test('formatGrams with zero', () {
      expect(numberFormat.formatGrams(0), '0 g');
    });

    test('formatMillimeters with zero', () {
      expect(numberFormat.formatMillimeters(0), '0 mm');
    });

    test('formatFileSize with zero', () {
      expect(numberFormat.formatFileSize(0), '0 bits');
    });

    // test('formatGrams with very large value', () {
    //   expect(numberFormat.formatGrams(1e12), '1000000 t');
    // });
    //
    // test('formatMillimeters with very large value', () {
    //   expect(numberFormat.formatMillimeters(1e12), '1000000 km');
    // });
    //
    // test('formatFileSize with very large value', () {
    //   expect(numberFormat.formatFileSize(1e20), '88.82 TB');
    // });

    test('formatGrams at kg boundary', () {
      expect(numberFormat.formatGrams(1000), '1 kg');
    });

    test('formatGrams at t boundary', () {
      expect(numberFormat.formatGrams(1000000), '1 t');
    });

    test('formatMillimeters at m boundary', () {
      expect(numberFormat.formatMillimeters(1000), '1 m');
    });

    test('formatMillimeters at km boundary', () {
      expect(numberFormat.formatMillimeters(1000000), '1 km');
    });

    test('formatFileSize at kB boundary', () {
      expect(numberFormat.formatFileSize(1024), '1 kB');
    });

    test('formatGrams with fractional grams', () {
      expect(numberFormat.formatGrams(0.1), '0.1 g');
    });

    test('formatMillimeters with fractional mm', () {
      expect(numberFormat.formatMillimeters(0.1), '0.1 mm');
    });

    test('formatFileSize with fractional bits', () {
      expect(numberFormat.formatFileSize(0.5), '0.5 bits');
    });
    //
    // test('formatGrams rounding', () {
    //   expect(numberFormat.formatGrams(1.005 * 1e6), '1.01 t');
    // });
    //
    // test('formatMillimeters rounding', () {
    //   expect(numberFormat.formatMillimeters(1.005 * 1e6), '1.01 km');
    // });
    //
    //
    // test('formatFileSize rounding', () {
    //   expect(numberFormat.formatFileSize(1.005 * 1024 * 1024), '1.01 MB');
    // });
  });
}
