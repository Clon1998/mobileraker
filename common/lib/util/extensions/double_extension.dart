/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

/// Taken from GETX project, original: https://github.com/jonataslaw/getx/blob/master/lib/get_utils/src/extensions/double_extensions.dart
extension Precision on double {
  double toPrecision(int fractionDigits) {
    var mod = pow(10, fractionDigits.toDouble()).toDouble();
    return ((this * mod).round().toDouble() / mod);
  }

  /// Returns true if the difference between this and [value] is less than [epsilon].
  /// [epsilon] is the maximum difference between the two numbers.
  /// [epsilon] must be positive.
  /// If [epsilon] is not provided, it defaults to 0.001.
  /// Example:
  /// ```dart
  /// 1.0001.closeTo(1); // true
  /// 1.0001.closeTo(1, 0.0001); // false
  /// ```
  bool closeTo(double value, [double epsilon = 0.001]) {
    return (this - value).abs() < epsilon;
  }
}
