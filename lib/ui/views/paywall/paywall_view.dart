import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/views/paywall/paywall_viewmodel.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stacked/stacked.dart';

class PaywallView extends ViewModelBuilderWidget<PaywallViewModel> {
  @override
  Widget builder(BuildContext context, PaywallViewModel model, Widget? child) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Support the Dev!'),
        ),
        drawer: NavigationDrawerWidget(curPath: Routes.paywallView),
        body: Center(
            child: LineChart(
          mainData(),
          swapAnimationDuration: Duration(milliseconds: 150), // Optional
          swapAnimationCurve: Curves.linear, // Optional
        )));
  }

  Widget? ff(PaywallViewModel model) {
    if (!model.dataReady) return FadingText('Fetching offers');

    if (model.isEntitlementActive('Supporter'))
      return Text('Yay! Thanks for supporting the App!');

    return TextButton(onPressed: model.buy, child: Text('Test-Buy'));
  }

  LineChartData mainData() {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: 1,
        verticalInterval: 1,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: const Color(0xff065393),
            strokeWidth: 1,
          );
        },
        getDrawingVerticalLine: (value) {
          return FlLine(
            color: const Color(0xffe30461),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(show: false),
      borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xff78ff31), width: 1)),
      minX: 0,
      maxX: 1200,
      minY: 0,
      maxY: 70,
      lineBarsData: [
        LineChartBarData(
          spots: dummyData(),
          isCurved: true,
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: false,
          ),
          belowBarData: BarAreaData(
            show: true,
          ),
        ),
      ],
    );
  }

  List<FlSpot> dummyData() {
    List<FlSpot> bl = <FlSpot>[];
    Random random = Random();
    for (int i = 0; i < 1200; i++) {

      bl.add(FlSpot(i.toDouble(), 40+20*sin(pi*i/100)));
    }
    return bl;
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Color(0xff68737d),
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );
    Widget text;
    switch (value.toInt()) {
      case 200:
        text = const Text('MAR', style: style);
        break;
      case 600:
        text = const Text('JUN', style: style);
        break;
      case 1000:
        text = const Text('SEP', style: style);
        break;
      default:
        text = const Text('', style: style);
        break;
    }

    return Padding(child: text, padding: const EdgeInsets.only(top: 8.0));
  }

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Color(0xff67727d),
      fontWeight: FontWeight.bold,
      fontSize: 15,
    );

    if (value % 10 != 0)
      return Container();

    return Text('${value.toStringAsFixed(0)}°C', style: style, textAlign: TextAlign.left);
  }

  @override
  PaywallViewModel viewModelBuilder(BuildContext context) => PaywallViewModel();
}
