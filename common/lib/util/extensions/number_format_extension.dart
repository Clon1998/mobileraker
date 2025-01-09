/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';

/// Units for weight
enum WeightUnit { g, kg, t }

/// Units for length
enum LengthUnit {
  um('µm'),
  mm('mm'),
  m('m'),
  km('km');

  const LengthUnit(this.name);

  final String name;
}

/// Units for file size
enum FileSizeUnit { bytes, kB, MB, GB, TB }

/// Extension on [NumberFormat] to provide additional formatting methods.
extension UnitFormatting on NumberFormat {
  static const _kilo = 1000;
  static const _kibi = 1024;

  /// Formats a given weight in grams to a string with appropriate units.
  String formatGrams(num g, [bool addUnit = true]) {
    // Determine the sign and work with absolute value
    final sign = g < 0 ? '-' : '';
    g = g.abs();
    var exp = 0;
    if (g > 0) {
      exp = (math.log(g) / math.log(_kilo)).floor().clamp(0, WeightUnit.values.length - 1);

      // Due to numerical inaccuracies, its better to devide the number by 1000 exp times rather than using math.pow
      // math.pow(1000, exp) is not always exactly 1000^exp
      for (var i = 0; i < exp; i++) {
        g /= _kilo;
      }
    }

    final unit = WeightUnit.values[exp];
    return addUnit ? '$sign${format(g)} ${unit.name}' : '$sign${format(g)}';
  }

  /// Formats a given length in millimeters to a string with appropriate units.
  String formatMillimeters(num mm, {bool useMicro = false}) {
    // Determine the sign and work with absolute value
    final sign = mm < 0 ? '-' : '';
    mm = mm.abs();

    var exp = 0;
    if (mm < 1 && useMicro) {
      mm *= 1000;
      exp = -1;
    } else if (mm > 0) {
      exp = ((math.log(mm) / math.log(_kilo)).floor()).clamp(0, LengthUnit.values.length - 2);

      // Due to numerical inaccuracies, its better to devide the number by 1000 exp times rather than using math.pow
      // math.pow(1000, exp) is not always exactly 1000^exp
      for (var i = 0; i < exp; i++) {
        mm /= _kilo;
      }
    }

    final unit = LengthUnit.values[exp + 1];
    return '$sign${format(mm)} ${unit.name}';
  }

  /// Formats a given file size in bytes to a string with appropriate units.
  String formatFileSize(num bytes) {
    // Determine the sign and work with absolute value
    final sign = bytes < 0 ? '-' : '';
    bytes = bytes.abs();

    var exp = 0;
    if (bytes > 0) {
      exp = (math.log(bytes) / math.log(_kibi)).floor().clamp(0, FileSizeUnit.values.length - 1);

      // Due to numerical inaccuracies, its better to devide the number by 1000 exp times rather than using math.pow
      // math.pow(1000, exp) is not always exactly 1000^exp
      for (var i = 0; i < exp; i++) {
        bytes /= _kibi;
      }
    }

    final unit = FileSizeUnit.values[exp];
    return '$sign${format(bytes)} ${unit.name}';
  }
}
