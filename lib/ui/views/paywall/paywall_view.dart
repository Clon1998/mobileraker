import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/components/graph_card_with_button.dart';
import 'package:mobileraker/ui/views/paywall/paywall_viewmodel.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stacked/stacked.dart';

class PaywallView extends ViewModelBuilderWidget<PaywallViewModel> {
  @override
  Widget builder(BuildContext context, PaywallViewModel model, Widget? child) {
    List<double> temperatureHistory = (model.isPrinterDataReady)
        ? model.printerData.extruder.temperatureHistory!
        : [];

    List<FlSpot>? dataExtruder = temperatureHistory
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return Scaffold(
        appBar: AppBar(
          title: const Text('Support the Dev!'),
        ),
        drawer: NavigationDrawerWidget(curPath: Routes.paywallView),
        body: Center(
            child: Column(
          children: [
            GraphCardWithButton(
                plotSpots: dataExtruder.sublist(900),
                child: Builder(builder: (context) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('name', style: Theme.of(context).textTheme.caption),
                      Text('11 °C',
                          style: Theme.of(context).textTheme.headline6),
                      Text('targetTemp'),
                    ],
                  );
                }),
                buttonChild: const Text('general.set'),
                onTap: null),
            Expanded(
              child: LineChart(
                mainData(model),
                swapAnimationDuration: Duration(milliseconds: 150),
                // Optional
                swapAnimationCurve: Curves.linear, // Optional
              ),
            ),
          ],
        )));
  }

  Widget? ff(PaywallViewModel model) {
    if (!model.dataReady(off)) return FadingText('Fetching offers');

    if (model.isEntitlementActive('Supporter'))
      return Text('Yay! Thanks for supporting the App!');

    return TextButton(onPressed: model.buy, child: Text('Test-Buy'));
  }

  LineChartData mainData(PaywallViewModel model) {
    List<double> temperatureHistory = (model.isPrinterDataReady)
        ? model.printerData.extruder.temperatureHistory!
        : [];

    var dataExtruder = temperatureHistory
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return LineChartData(
      gridData: FlGridData(
        show: false,
      ),
      titlesData: FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      minX: 0,
      minY: 0,
      // maxY: temperatureHistory.reduce(max)+10,
      lineTouchData: LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: dataExtruder,
          // spots: dummyData(),
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
      bl.add(FlSpot(i.toDouble(), 40 + 20 * sin(pi * i / 100)));
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

    if (value % 10 != 0) return Container();

    return Text('${value.toStringAsFixed(0)}°C',
        style: style, textAlign: TextAlign.left);
  }

  @override
  PaywallViewModel viewModelBuilder(BuildContext context) => PaywallViewModel();
}
