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

    return FutureBuilder<String>(
      future: rootBundle.loadString('assets/vector/spool-yellow-small.svg'),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return SvgPicture.string(
            _getSvgString(snapshot.data!, colorVariant),
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

  String _getSvgString(String svg, String? colorVariant) {
    if (colorVariant == null) return svg;

    return svg.replaceAll('fill="#FCEE21"', 'fill="#$color"').replaceAll('fill="#FFCD00"', 'fill="#$colorVariant"');
  }
}
