/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'spool_widget.g.dart';

// Used to ensure we only load the SVG once
@Riverpod(keepAlive: true)
Future<String> _svg(_SvgRef ref) async {
  return rootBundle.loadString('assets/vector/spool-yellow-small.svg');
}

@Riverpod(keepAlive: true)
Future<String> _coloredSpool(_ColoredSpoolRef ref, String color, Brightness brightness) async {
  var rawSvg = await ref.watch(_svgProvider.future);
  // A color variant of the fill color to ensure the spool is visible on any background
  var colorVariant = _getColorVariant(color);

  // Change the spool color to a lighter color for dark mode
  if (brightness == Brightness.dark) {
    // Change the spool color to a lighter color for dark mode
    rawSvg = rawSvg.replaceAll('fill="#282828"', 'fill="#5B5B5B"').replaceAll('fill="#1E1E1E"', 'fill="#4E4E4E"');
  }

  // Change the spool's filament color to the selected color
  return rawSvg.replaceAll('fill="#FCEE21"', 'fill="#$color"').replaceAll('fill="#FFCD00"', 'fill="#$colorVariant"');
}

String? _getColorVariant(String color) {
  var col = Color(int.tryParse(color, radix: 16) ?? Colors.white24.value);
  final HSLColor hsl = HSLColor.fromColor(col);
  final lightnessAdjustment = ThemeData.estimateBrightnessForColor(col) == Brightness.dark ? 0.05 : -0.05;

  return hsl.withLightness((hsl.lightness + lightnessAdjustment).clamp(0, 1)).toColor().value.toRadixString(16);
}

class SpoolWidget extends ConsumerWidget {
  const SpoolWidget({super.key, String? color, this.height = 55, double? width})
      : color = color ?? '333333',
        width = width ?? 0.45 * height;

  final String color;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var brightness = Theme.of(context).brightness;

    var model = ref.watch(_coloredSpoolProvider(color, brightness));

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: height,
        maxWidth: width,
      ),
      child: switch (model) {
        AsyncData(:final value) => SizedBox.expand(
            child: SvgPicture.string(
              value,
              height: height,
              width: width,
            ),
          ),
        _ => const SizedBox.expand()
      },
    );
  }
}
