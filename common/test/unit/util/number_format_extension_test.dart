/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

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

    test('formatFileSize with bytes', () {
      expect(numberFormat.formatFileSize(800), '800 bytes');
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

    test('format negative weight', () {
      expect(numberFormat.formatGrams(-100), '-100 g');
    });

    test('format negative length', () {
      expect(numberFormat.formatMillimeters(-100), '-100 mm');
    });

    test('format negative file size', () {
      expect(numberFormat.formatFileSize(-1024), '-1 kB');
    });

    test('formatGrams with zero', () {
      expect(numberFormat.formatGrams(0), '0 g');
    });

    test('formatMillimeters with zero', () {
      expect(numberFormat.formatMillimeters(0), '0 mm');
    });

    test('formatFileSize with zero', () {
      expect(numberFormat.formatFileSize(0), '0 bytes');
    });

    test('formatGrams with number bigger than last unit', () {
      final total = WeightUnit.values.length;
      final last = WeightUnit.values[total - 1];

      // calculate the value for the last unit
      final lastValue = pow(1000, total);

      expect(numberFormat.formatGrams(lastValue), '1000 ${last.name}',
          reason: 'Expected $lastValue g to be formatted as 1000 ${last.name}');
    });

    test('formatMillimeters with number bigger thans last unit', () {
      final total = LengthUnit.values.length;
      final last = LengthUnit.values[total - 1];

      // calculate the value for the last unit
      final lastValue = pow(1000, total - 1); // -1 because we include µm

      expect(numberFormat.formatMillimeters(lastValue), '1000 ${last.name}',
          reason: 'Expected $lastValue mm to be formatted as 1000 ${last.name}');
    });
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
