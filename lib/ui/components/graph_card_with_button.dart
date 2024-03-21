/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:fl_chart/fl_chart.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

class GraphCardWithButton extends StatelessWidget {
  static const double radius = 15;

  const GraphCardWithButton({
    super.key,
    this.backgroundColor,
    this.graphColor,
    required this.plotSpots,
    required this.builder,
    required this.buttonChild,
    required this.onTap,
  });

  final Color? backgroundColor;
  final Color? graphColor;
  final WidgetBuilder builder;
  final Widget buttonChild;
  final VoidCallback? onTap;
  final List<FlSpot> plotSpots;

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    var _backgroundColor =
        backgroundColor ?? themeData.colorScheme.surfaceVariant;
    var _graphColor = graphColor ??
        ((Theme.of(context).brightness == Brightness.dark)
            ? _backgroundColor.brighten(15)
            : _backgroundColor.darken(15));
    var _onBackgroundColor =
        (ThemeData.estimateBrightnessForColor(_backgroundColor) ==
                Brightness.dark
            ? Colors.white
                .blendAlpha(themeData.colorScheme.primary.brighten(20), 0)
            : Colors.black
                .blendAlpha(themeData.colorScheme.primary.brighten(20), 0));

    return Container(
      padding: CardTheme.of(context).margin ?? const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(radius)),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Only way i found to expand the stack completly...
                Container(width: double.infinity),
                Positioned.fill(
                  top: radius,
                  child: _Chart(
                    graphColor: _graphColor,
                    plotSpots: plotSpots,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
                  child: Theme(
                    data: themeData.copyWith(
                      textTheme: themeData.textTheme.apply(
                        bodyColor: _onBackgroundColor,
                        displayColor: _onBackgroundColor,
                      ),
                      iconTheme: themeData.iconTheme.copyWith(color: _onBackgroundColor),
                    ),
                    child: DefaultTextStyle(
                      style: TextStyle(color: _onBackgroundColor),
                      child: Builder(builder: builder),
                    ),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              maximumSize: const Size.fromHeight(48),
              padding: EdgeInsets.zero,
              shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(radius)),
              ),
              foregroundColor: themeData.colorScheme.onPrimary,
              backgroundColor: themeData.colorScheme.primary,
              // onPrimary: Theme.of(context).colorScheme.onSecondary,
              disabledForegroundColor: themeData.colorScheme.onPrimary.withOpacity(0.38),
            ),
            onPressed: onTap,
            child: buttonChild,
          ),
        ],
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({
    super.key,
    required this.graphColor,
    required this.plotSpots,
  });

  final Color graphColor;

  final List<FlSpot> plotSpots;

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: 0,
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: plotSpots,
            color: graphColor,
            isCurved: true,
            barWidth: 0,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: graphColor,
              applyCutOffY: true,
              cutOffY: 0,
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 10),
      // Optional
      curve: Curves.easeInOutCubic, // Optional
    );
  }
}
