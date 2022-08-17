import 'package:fl_chart/fl_chart.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

class GraphCardWithButton extends StatelessWidget {
  static const double radius = 15;

  const GraphCardWithButton({
    Key? key,
    this.backgroundColor,
    this.graphColor,
    required this.plotSpots,
    required this.child,
    required this.buttonChild,
    required this.onTap,
  }) : super(key: key);

  final Color? backgroundColor;
  final Color? graphColor;
  final Widget child;
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(radius))),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Only way i found to expand the stack completly...
                Container(
                  width: double.infinity,
                ),
                Positioned.fill(
                  top: radius,
                  child: _Chart(
                    graphColor: _graphColor,
                    plotSpots: plotSpots,
                  )
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
                  child: Theme(
                      data: themeData.copyWith(
                          textTheme: themeData.textTheme.apply(
                              bodyColor: _onBackgroundColor,
                              displayColor: _onBackgroundColor),
                          iconTheme: themeData.iconTheme
                              .copyWith(color: _onBackgroundColor)),
                      child: DefaultTextStyle(
                        style: TextStyle(color: _onBackgroundColor),
                        child: child,
                      )),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              padding: EdgeInsets.zero,
              shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(radius)),
              ),
              primary: themeData.colorScheme.onPrimary,
              backgroundColor: themeData.colorScheme.primary,
              // onPrimary: Theme.of(context).colorScheme.onSecondary,
              onSurface: themeData.colorScheme.onPrimary,
            ),
            onPressed: onTap,
            child: buttonChild,
          )
        ],
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({
    Key? key,
    required this.graphColor,
    required this.plotSpots,
  }) : super(key: key);

  final Color graphColor;

  final List<FlSpot> plotSpots;

  @override
  Widget build(BuildContext context) {

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: 0,
        lineTouchData: LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: plotSpots,
            color: graphColor,
            isCurved: true,
            barWidth: 0,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: false,
            ),
            belowBarData: BarAreaData(
              show: true,
              color: graphColor,
            ),
          ),
        ],
      ),
      swapAnimationDuration: const Duration(milliseconds: 10),
      // Optional
      swapAnimationCurve: Curves.easeInOutCubic, // Optional
    );
  }
}
