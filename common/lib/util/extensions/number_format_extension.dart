/*
 * Copyright (c) 2024. Patrick Schmidt.
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
  String formatGrams(num g) {
    if (g < 0) throw ArgumentError('Weight cannot be negative');

    if (g < _kilo) {
      return '${format(g)} ${WeightUnit.g.name}';
    } else {
      final exp = (math.log(g) / math.log(_kilo)).floor();
      g /= math.pow(_kilo, exp);
      final unit = WeightUnit.values[exp.clamp(0, WeightUnit.values.length - 1)];
      return '${format(g)} ${unit.name}';
    }
  }

  /// Formats a given length in millimeters to a string with appropriate units.
  String formatMillimeters(num mm, {bool useMicro = false}) {
    if (mm < 0) throw ArgumentError('Length cannot be negative');

    if (mm < 1 && useMicro) {
      return '${format(mm * _kilo)} ${LengthUnit.um.name}';
    } else if (mm < _kilo) {
      return '${format(mm)} ${LengthUnit.mm.name}';
    } else {
      final exp = (math.log(mm) / math.log(_kilo)).floor();
      mm /= math.pow(_kilo, exp);
      final unit = LengthUnit.values[exp + 1]; // +1 because we start from mm, not um
      return '${format(mm)} ${unit.name}';
    }
  }

  /// Formats a given file size in bits to a string with appropriate units.
  String formatFileSize(num bits) {
    if (bits < 0) throw ArgumentError('File size cannot be negative');

    if (bits < _kibi) {
      return '${format(bits / 8)} ${FileSizeUnit.bytes.name}';
    } else {
      final exp = (math.log(bits) / math.log(_kibi)).floor();
      bits /= math.pow(_kibi, exp);
      final unit = FileSizeUnit.values[exp.clamp(0, FileSizeUnit.values.length - 1)];
      return '${format(bits)} ${unit.name}';
    }
  }
}
