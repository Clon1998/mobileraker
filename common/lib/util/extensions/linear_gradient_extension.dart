/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

/// An extension on the [LinearGradient] class.
///
/// This extension adds a method to the [LinearGradient] class that allows
/// you to get the color at a specific position within the gradient.
extension LinearGradientExtension on LinearGradient {
  /// Returns the color at a specific position within the gradient.
  ///
  /// The [position] parameter should be a double between 0.0 and 1.0, where
  /// 0.0 represents the start of the gradient and 1.0 represents the end.
  ///
  /// If the gradient has defined stops, this method will interpolate between
  /// the two colors that surround the specified position.
  ///
  /// If the gradient does not have defined stops, this method will assume a
  /// uniform distribution of colors and interpolate accordingly.
  ///
  /// If the specified position is outside the range of defined stops (if any),
  /// this method will return the color at the last stop.
  ///
  /// Throws an [AssertionError] if the [position] is not between 0.0 and 1.0.
  Color getColorAtPosition(double position) {
    assert(position >= 0.0 && position <= 1.0, 'Position should be between 0 and 1');

    List<Color> colors = this.colors;
    List<double>? stops = this.stops;

    if (stops == null || stops.isEmpty) {
      // If no stops are specified, assume uniform distribution
      double step = 1.0 / (colors.length - 1);
      int index = (position / step).floor().clamp(0, colors.length - 2);
      double t = (position - index * step) / step;
      return Color.lerp(colors[index], colors[index + 1], t)!;
    }

    for (int i = 0; i < stops.length - 1; i++) {
      if (position >= stops[i] && position <= stops[i + 1]) {
        double t = (position - stops[i]) / (stops[i + 1] - stops[i]);
        return Color.lerp(colors[i], colors[i + 1], t)!;
      }
    }

    // If the position is outside the range of stops, return the color at the last stop.
    return colors.last;
  }
}
