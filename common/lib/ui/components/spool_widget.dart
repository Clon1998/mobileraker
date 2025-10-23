/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/svg/remapping_color_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'spool_widget.g.dart';

@riverpod
ColorMapper? _spoolColorMapper(Ref ref, String hexColor, Brightness brightness) {
  int? hexValue = int.tryParse(hexColor, radix: 16);
  if (hexValue == null) {
    return null;
  }

  // If the hex color does not have an alpha channel, add it full bits to the front
  if (hexColor.length == 6) {
    hexValue = 0xFF000000 | hexValue;
  }

  final color = Color(hexValue);
  // A color variant of the fill color to ensure the spool is visible on any background
  final colorVariant = SpoolWidget.getColorVariant(color);

  var isDark = brightness == Brightness.dark;
  Map<int, int> mappings = {
    // These colors are for the rims of the spool
    if (isDark) ...{0xFF282828: 0xFF7A7979, 0XFF1E1E1E: 0xFF4E4E4E},
    // These are the main body of the spool
    0xFFFCEE21: color.toARGB32(),
    0xFFFFCD00: colorVariant.toARGB32(),
  };

  return RemappingColorMapper(mappings);
}

class SpoolWidget extends ConsumerWidget {
  const SpoolWidget({super.key, String? color, this.height = 55, double? width})
    : color = color ?? '333333',
      width = width ?? 0.45 * height,
      assert(
        color == null || color.length == 6 || color.length == 8,
        'If color is provided, it must be a hex color code with or without alpha channel',
      ),
      assert(height > 0, 'height must be greater than 0');

  final String color;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var brightness = Theme.of(context).brightness;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height, maxWidth: width),
      child: SizedBox.expand(
        child: SvgPicture.asset(
          'assets/vector/spool-yellow-small.svg',
          height: height,
          width: width,
          colorMapper: ref.watch(_spoolColorMapperProvider(color, brightness)),
        ),
      ),
    );
  }

  static Color getColorVariant(Color color) {
    final HSLColor hsl = HSLColor.fromColor(color);
    final lightnessAdjustment = ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? 0.05 : -0.05;

    return hsl.withLightness((hsl.lightness + lightnessAdjustment).clamp(0, 1)).toColor();
  }
}
