/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

/// A class that scales a number from one range to another.
///
/// The `NumScaler` class is used to scale a number from an original range
/// (defined by `originMin` and `originMax`) to a target range
/// (defined by `targetMin` and `targetMax`).
///
/// Example:
/// ```dart
/// var scaler = NumScaler(originMin: 0, originMax: 10, targetMin: 0, targetMax: 100);
/// var scaledValue = scaler.scale(5);  // Returns 50
/// ```
class NumScaler {
  /// Creates a `NumScaler`.
  ///
  /// The `originMin` and `originMax` parameters define the original range.
  /// The `targetMin` and `targetMax` parameters define the target range.
  const NumScaler({
    required this.originMin,
    required this.originMax,
    required this.targetMin,
    required this.targetMax,
  });

  /// The minimum value of the original range.
  final num originMin;

  /// The maximum value of the original range.
  final num originMax;

  /// The minimum value of the target range.
  final num targetMin;

  /// The maximum value of the target range.
  final num targetMax;

  /// Scales a number from the original range to the target range.
  ///
  /// The `value` parameter is the number to be scaled.
  ///
  /// Returns the scaled number.
  num scale(num value) {
    // clamp provided value to origin range
    value = value.clamp(originMin, originMax);
    return (value - originMin) / (originMax - originMin) * (targetMax - targetMin) + targetMin;
  }
}
