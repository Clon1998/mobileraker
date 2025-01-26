/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

extension NumberToColors on ColorScheme {
  (Color barColor, Color belowColor) colorsForEntry(int i) {
    final materialColors = [
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.lime,
      Colors.indigo,
    ];

    if (i < materialColors.length) {
      final color = materialColors[i];
      return (color, color.withValues(alpha: 0.2));
    }

    // Fallback method
    // Fallback method using HSL hue ring
    final hue = (i * 37) % 360; // Use a prime number to distribute colors more evenly
    final color = HSLColor.fromAHSL(
      1.0,
      hue.toDouble(),
      0.7, // Consistent saturation
      0.5, // Consistent lightness
    ).toColor();

    return (color, color.withValues(alpha: 0.2));
  }
}
