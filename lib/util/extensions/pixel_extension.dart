/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/leds/led.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

extension UiColorLedExtension on Pixel {
  Color get rgbColor => Color.from(
        alpha: 1,
        red: red,
        green: green,
        blue: blue,
      );

  Color get rgbwColor => rgbColor.blend(Colors.white, (100 * white).toInt());
}
