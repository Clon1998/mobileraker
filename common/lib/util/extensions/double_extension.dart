/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:easy_localization/easy_localization.dart';

/// Taken from GETX project, original: https://github.com/jonataslaw/getx/blob/master/lib/get_utils/src/extensions/double_extensions.dart
extension Precision on double {
  double toPrecision(int fractionDigits) {
    var mod = pow(10, fractionDigits.toDouble()).toDouble();
    return ((this * mod).round().toDouble() / mod);
  }

  String formatGramms(NumberFormat numberFormat) {
    var g = this;
    final String suffix;
    if (g < 1000) {
      suffix = 'g';
    } else if (g < 1000000) {
      g /= 1000;
      suffix = 'kg';
    } else {
      g /= 1000000;
      suffix = 't';
    }
    return '${numberFormat.format(g)} $suffix';
  }

  String formatMiliMeters(NumberFormat numberFormat) {
    var mm = this;
    final String suffix;
    if (mm < 1000) {
      suffix = 'mm';
    } else if (mm < 1000000) {
      mm /= 1000;
      suffix = 'm';
    } else {
      mm /= 1000000;
      suffix = 'km';
    }
    return '${numberFormat.format(mm)} $suffix';
  }
}