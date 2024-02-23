/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

class SpoolWidget extends StatelessWidget {
  const SpoolWidget({super.key, this.color = '333333', this.height = 55, this.width = 55});

  final String? color;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colorVariant = _getColorVariant();

    var brightness = Theme.of(context).brightness;

    return FutureBuilder<String>(
      future: rootBundle.loadString('assets/vector/spool-yellow-small.svg'),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return SvgPicture.string(
            _getSvgString(snapshot.data!, colorVariant, brightness),
            height: height,
            width: width,
          );
        } else {
          // Return ConstraintedBox to avoid layout issues
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: height,
              maxWidth: width,
            ),
            child: const SizedBox.expand(),
          );
        }
      },
    );
  }

  String? _getColorVariant() {
    if (color == null) return null;

    var col = Color(int.tryParse(color!, radix: 16) ?? Colors.white24.value);
    final HSLColor hsl = HSLColor.fromColor(col);
    final lightnessAdjustment = ThemeData.estimateBrightnessForColor(col) == Brightness.dark ? 0.05 : -0.05;

    return hsl.withLightness((hsl.lightness + lightnessAdjustment).clamp(0, 1)).toColor().value.toRadixString(16);
  }

  String _getSvgString(String svg, String? colorVariant, Brightness brightness) {
    if (colorVariant == null) return svg;

    if (brightness == Brightness.dark) {
      // Change the spool color to a lighter color for dark mode
      svg = svg.replaceAll('fill="#282828"', 'fill="#5B5B5B"').replaceAll('fill="#1E1E1E"', 'fill="#4E4E4E"');
    }

    return svg.replaceAll('fill="#FCEE21"', 'fill="#$color"').replaceAll('fill="#FFCD00"', 'fill="#$colorVariant"');
  }
}
