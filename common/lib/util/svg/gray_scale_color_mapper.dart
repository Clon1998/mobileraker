/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:ui';

import 'package:flutter_svg/svg.dart';

class GrayScaleColorMapper extends ColorMapper {
  const GrayScaleColorMapper();

  @override
  Color substitute(
      String? id,
      String elementName,
      String attributeName,
      Color elementColor,
      ) {
    // Convert to grayscale using luminance formula
    // This preserves the relative brightness of the original color
    final double gray = (0.299 * elementColor.r + 0.587 * elementColor.g + 0.114 * elementColor.b);

    return Color.from(
      alpha: elementColor.a,
      red:gray,
      green: gray,
      blue: gray,
    );
  }
}
