/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/bed_mesh/bed_mesh.dart';
import 'package:common/util/extensions/linear_gradient_extension.dart';
import 'package:common/util/num_scaler.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

class BedMeshPlot extends StatelessWidget {
  final BedMesh? bedMesh;
  final (double, double) bedMin; // values from config
  final (double, double) bedMax; // values from config
  final bool isProbed;

  const BedMeshPlot({
    super.key,
    required this.bedMesh,
    required this.bedMin,
    required this.bedMax,
    this.isProbed = true,
  });

  @override
  Widget build(BuildContext context) {
    if (bedMesh?.profileName?.isNotEmpty != true) {
      return Center(child: const Text('bottom_sheets.bedMesh.no_mesh_loaded').tr());
    }

    var meshCords = (isProbed) ? bedMesh!.probedCoordinates : bedMesh!.meshCoordinates;
    var zRange = (isProbed) ? bedMesh!.zValueRangeProbed : bedMesh!.zValueRangeMesh;

    NumScaler scaler = NumScaler(
      originMin: zRange.$1,
      originMax: zRange.$2,
      targetMin: 0,
      targetMax: 1,
    );

    NumberFormat formatterXY = NumberFormat('#0.00', context.locale.toStringWithSeparator());
    NumberFormat formatterZ = NumberFormat('#0.0000', context.locale.toStringWithSeparator());

    // Theme stuff
    var themeData = Theme.of(context);
    Color backgroundColor = (themeData.colorScheme.brightness == Brightness.light)
        ? themeData.colorScheme.surface.darken(5)
        : themeData.colorScheme.surface;
    Color gridColor = (themeData.colorScheme.brightness == Brightness.light)
        ? backgroundColor.darken(10)
        : backgroundColor.lighten(10);

    Color tooltipBackground, tooltipForeground;
    if (themeData.colorScheme.brightness == Brightness.light) {
      tooltipBackground = Colors.black;
      tooltipForeground = Colors.white;
    } else {
      tooltipBackground = Colors.white.darken(2);
      tooltipForeground = Colors.black;
    }
    var tooltipLabelStyle = TextStyle(color: tooltipForeground);

    // Define the gradients
    LinearGradient gradient = gradientForRange(zRange.$1, zRange.$2, false, scaler);

    return AspectRatio(
      aspectRatio: (bedMax.$1 - bedMin.$1) / (bedMax.$2 - bedMin.$2),
      child: ScatterChart(
        ScatterChartData(
          backgroundColor: backgroundColor,
          minX: bedMin.$1,
          maxX: bedMax.$1,
          minY: bedMin.$2,
          maxY: bedMax.$2,
          // set the grid lines to show every 50mm
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            getDrawingHorizontalLine: (value) => FlLine(color: gridColor),
            drawVerticalLine: true,
            getDrawingVerticalLine: (value) => FlLine(color: gridColor),
            horizontalInterval: 50,
            verticalInterval: 50,
          ),
          titlesData: const FlTitlesData(show: false),

          scatterSpots: [
            for (var cord in meshCords)
              _ZScatterSpot(
                cord[0],
                cord[1],
                cord[2],
                dotPainter: FlDotCirclePainter(
                  color: gradient.getColorAtPosition(scaler.scale(cord[2]).toDouble()),
                  radius: 15,
                ),
              ),
          ],
          scatterTouchData: ScatterTouchData(
            touchTooltipData: ScatterTouchTooltipData(
              tooltipHorizontalOffset: 10,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              tooltipBgColor: tooltipBackground,
              getTooltipItems: (touchedSpot) {
                _ZScatterSpot spot = touchedSpot as _ZScatterSpot;
                return ScatterTooltipItem(
                  '',
                  textAlign: TextAlign.start,
                  textStyle: tooltipLabelStyle,
                  children: [
                    const TextSpan(text: 'X: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: '${formatterXY.format(spot.x)}\n'),
                    const TextSpan(text: 'Y: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: '${formatterXY.format(spot.y)}\n'),
                    const TextSpan(text: 'Z: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: formatterZ.format(spot.z)),
                  ],
                );
              },
            ),
          ),
        ),
        swapAnimationDuration: kThemeAnimationDuration, // Optional
        swapAnimationCurve: Curves.linear, // Optional
      ),
    );
  }
}

class _ZScatterSpot extends ScatterSpot {
  _ZScatterSpot(super.x, super.y, this.z, {super.dotPainter, super.show});

  final double z;

  @override
  ScatterSpot copyWith({
    double? x,
    double? y,
    double? z,
    bool? show,
    FlDotPainter? dotPainter,
  }) {
    return _ZScatterSpot(
      x ?? this.x,
      y ?? this.y,
      z ?? this.z,
      show: show ?? this.show,
      dotPainter: dotPainter ?? this.dotPainter,
    );
  }

  @override
  List<Object?> get props => [
        x,
        y,
        z,
        show,
        dotPainter,
      ];
}

LinearGradient gradientForRange(double min, double max, [bool inverse = false, NumScaler? scaler]) {
  scaler ??= NumScaler(
    originMin: min,
    originMax: max,
    targetMin: 0,
    targetMax: 1,
  );
  assert(scaler.targetMin == 0 && scaler.targetMax == 1, 'Target min and max must be 0 and 1');
  // Stops msut be equal to colors length and should go from 0 (min) to 1 (max) thats why we scale...

  if (min == 0 && max == 0) {
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.blue, Colors.red],
    );
  }

  return LinearGradient(
    begin: inverse ? Alignment.bottomCenter : Alignment.topCenter,
    end: inverse ? Alignment.topCenter : Alignment.bottomCenter,
    colors: [
      if (min < 0) Colors.blue,
      Colors.white,
      if (max > 0) Colors.red,
    ],
    stops: [
      scaler.scale(min).toDouble(),
      if (min < 0 && max > 0) scaler.scale(0).toDouble(),
      scaler.scale(max).toDouble(),
    ],
  );
}
