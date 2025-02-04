/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/time_series_entry.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class GraphCardWithButton extends StatelessWidget {
  static const double radius = 15;

  const GraphCardWithButton({
    super.key,
    this.backgroundColor,
    this.graphColor,
    required this.tempStore,
    required this.topChild,
    required this.buttonChild,
    required this.onTap,
    this.onLongPress,
    this.onTapGraph,
  });

  final Color? backgroundColor;
  final Color? graphColor;
  final Widget topChild;
  final Widget buttonChild;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onTapGraph;
  final List<TemperatureSensorSeriesEntry> tempStore;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final bgColor = backgroundColor ?? themeData.colorScheme.surfaceContainer;
    final gcColor = graphColor ?? (themeData.brightness == Brightness.dark ? bgColor.brighten(15) : bgColor.darken(15));
    final onBackgroundColor = ThemeData.estimateBrightnessForColor(bgColor) == Brightness.dark
        ? Colors.white.blendAlpha(themeData.colorScheme.primary.brighten(20), 0)
        : Colors.black.blendAlpha(themeData.colorScheme.primary.brighten(20), 0);

    return Padding(
      padding: CardTheme.of(context).margin ?? const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onTapGraph,
            child: Container(
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(radius)),
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  SizedBox(width: double.infinity),
                  Positioned.fill(top: radius, child: _Chart(graphColor: gcColor, tempStore: tempStore)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
                    child: Theme(
                      data: themeData.copyWith(
                        textTheme: themeData.textTheme.apply(
                          bodyColor: onBackgroundColor,
                          displayColor: onBackgroundColor,
                        ),
                        iconTheme: themeData.iconTheme.copyWith(color: onBackgroundColor),
                      ),
                      child: topChild,
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              maximumSize: const Size.fromHeight(48),
              padding: EdgeInsets.zero,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
              ),
              foregroundColor: themeData.colorScheme.onPrimary,
              backgroundColor: themeData.colorScheme.primary,
              disabledForegroundColor: themeData.colorScheme.onPrimary.withOpacity(0.38),
            ),
            onPressed: onTap,
            onLongPress: onLongPress,
            child: buttonChild,
          ),
        ],
      ),
    );
  }
}

class _Chart extends StatefulWidget {
  const _Chart({
    super.key,
    required this.graphColor,
    required this.tempStore,
  });

  final Color graphColor;
  final List<TemperatureSensorSeriesEntry> tempStore;

  @override
  State<_Chart> createState() => _ChartState();
}

class _ChartState extends State<_Chart> {
  int maxStoreSize = 300;

  late List<TemperatureSensorSeriesEntry> _tempStore;
  ChartSeriesController? _chartSeriesController;
  DateTime _last = DateTime(1990);

  @override
  void initState() {
    super.initState();
    _tempStore = widget.tempStore;
    if (_tempStore.isNotEmpty) {
      _last = _tempStore.last.time;
    }
  }

  @override
  void didUpdateWidget(_Chart oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Efficiently update data without rebuilding the widget
    if (!identical(widget.tempStore, oldWidget.tempStore)) {
      if (_chartSeriesController == null) {
        setState(() {
          _tempStore = widget.tempStore;
        });
      } else {
        _syncStoreDataToChart(widget.tempStore);
      }
    }
  }

  void _syncStoreDataToChart(List<TemperatureSensorSeriesEntry> newStore) {
    if (newStore.isEmpty) return; // Avoid flickering when interacting

    final latestTimestamp = newStore.last.time;
    if (latestTimestamp.isBefore(_last)) return;

    // Calculate how many new entries we need to add
    final int entriesToAdd = latestTimestamp.difference(_last).inSeconds;
    if (entriesToAdd == 0) return;

    final toAdd = <TemperatureSensorSeriesEntry>[];

    // Collect only new points
    for (var i = newStore.length - 1; i >= 0; i--) {
      final point = newStore[i];
      if (!point.time.isAfter(_last)) break;
      toAdd.insert(0, point);
    }

    // This is nessesary due to a bug in the lib that complaints if more than 50% of the data is removed...
    if (toAdd.length > maxStoreSize / 2) {
      _tempStore.clear();
      _tempStore.addAll(newStore);
      _chartSeriesController?.updateDataSource();
      _last = latestTimestamp;
      return;
    }

    if (toAdd.isEmpty) return;

    int removed = 0;

    // Ensure we do not exceed maxStoreSize
    if ((_tempStore.length + toAdd.length) > maxStoreSize) {
      final toRemove = (_tempStore.length + toAdd.length) - maxStoreSize;
      _tempStore.removeRange(0, toRemove);
      removed = toRemove;
    }

    int lenAfterRemoval = _tempStore.length;
    _tempStore.addAll(toAdd);

    _chartSeriesController?.updateDataSource(
      addedDataIndexes: List.generate(toAdd.length, (index) => lenAfterRemoval + index),
      // We need to remove "From the back" because the lib does some bad shit..
      removedDataIndexes: List.generate(removed, (index) => removed - (1 + index)),
    );

    _last = latestTimestamp;
  }

  @override
  Widget build(BuildContext context) {
    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(isVisible: false),
      primaryYAxis: NumericAxis(
        isVisible: false,
        minimum: 0,
        rangePadding: ChartRangePadding.none,
      ),
      plotAreaBorderWidth: 0,
      plotAreaBorderColor: Colors.transparent,
      margin: const EdgeInsets.all(0),
      series: [
        AreaSeries<TemperatureSensorSeriesEntry, DateTime>(
          animationDuration: 0,
          color: widget.graphColor,
          dataSource: _tempStore,
          xValueMapper: (point, _) => point.time,
          yValueMapper: (point, _) => point.temperature,
          onRendererCreated: (ChartSeriesController controller) => _chartSeriesController = controller,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tempStore.clear();
    super.dispose();
  }
}
