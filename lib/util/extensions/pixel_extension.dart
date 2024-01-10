/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/leds/led.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

extension UiColorLedExtension on Pixel {
  Color get rgbColor => Color.fromARGB(
        255,
        (255 * red).toInt(),
        (255 * green).toInt(),
        (255 * blue).toInt(),
      );

  Color get rgbwColor => rgbColor.blend(Colors.white, (100 * white).toInt());
}
