/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:ui';

import 'package:flutter_svg/flutter_svg.dart';

class RemappingColorMapper extends ColorMapper {
  const RemappingColorMapper(this.mappings);

  final Map<int, int> mappings;

  @override
  Color substitute(String? id, String elementName, String attributeName, Color elementColor) {
    final mappedValue = mappings[elementColor.toARGB32()];

    if (mappedValue != null) {
      return Color(mappedValue);
    }
    return elementColor;
  }
}
