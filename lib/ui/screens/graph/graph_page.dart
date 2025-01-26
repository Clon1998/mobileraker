/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
import 'package:common/data/model/time_series_entry.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/moonraker/temperature_store_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../service/ui/bottom_sheet_service_impl.dart';

part 'graph_page.g.dart';

class GraphPage extends HookConsumerWidget {
  final String machineUUID;

  const GraphPage({super.key, required this.machineUUID});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      );

      return () => SystemChrome.setPreferredOrientations([]);
    });
    return _GraphPage(machineUUID: machineUUID);
  }
}

class _GraphPage extends ConsumerWidget {
  const _GraphPage({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_graphPageControllerProvider(machineUUID).notifier);
    final (maxTemp, series) = ref.watch(_graphPageControllerProvider(machineUUID));

    return Scaffold(
      appBar: AppBar(
        title: Text('pages.temp_chart.title').tr(),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () {
            SystemChrome.setPreferredOrientations([]).whenComplete(Navigator.of(context).pop);
          },
        ),
        actions: [
          IconButton(
            onPressed: controller.openFilterSheet,
            icon: Icon(Icons.legend_toggle),
          ),
        ],
      ),
      body: SafeArea(
        minimum: EdgeInsets.only(top: 15, right: 44.0),
        child: SfCartesianChart(
          enableAxisAnimation: true,
          trackballBehavior: TrackballBehavior(
            enable: true,
            shouldAlwaysShow: false,
            activationMode: ActivationMode.singleTap,
            markerSettings: TrackballMarkerSettings(
              shape: DataMarkerType.circle,
              markerVisibility: TrackballVisibilityMode.visible,
            ),
            tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
            // builder: (BuildContext context, TrackballDetails trackballDetails) {
            //
            //   logger.w('TrackballDetails: ${trackballDetails.groupingModeInfo?.currentPointIndices}');
            //
            //
            //   for (LineSeriesRenderer sr in trackballDetails.groupingModeInfo?.visibleSeriesList ?? []) {
            //     logger.w(sr.dataSource);
            //   }
            //
            //   logger.w('TrackballDetails: ${trackballDetails.groupingModeInfo?.points}');
            //   logger.w('TrackballDetails: ${trackballDetails.groupingModeInfo?.visibleSeriesIndices}');
            //   logger.w('TrackballDetails: ${trackballDetails.groupingModeInfo?.visibleSeriesList}');
            //
            //   return Container(
            //     width: 70,
            //     decoration:
            //       const BoxDecoration(color: Color.fromRGBO(66, 244, 164, 1)),
            //     child: Text('${trackballDetails.point?.cumulative}')
            //   );
            // },
            tooltipSettings: InteractiveTooltip(
              enable: true,
              format: 'series.name: point.y°C',
            ),
            // tooltipSettings: InteractiveTooltip(enable: true),
          ),
          onChartTouchInteractionDown: (ChartTouchInteractionArgs args) => controller.updateTooltip(true),
          onChartTouchInteractionUp: (ChartTouchInteractionArgs args) => controller.updateTooltip(false),
          primaryXAxis: DateTimeAxis(name: 'Time'),
          primaryYAxis: NumericAxis(
            title: AxisTitle(text: tr('pages.temp_chart.chart_y_axis')),
            minimum: 0,
            maximum: maxTemp,
          ),
          series: series,
        ),
      ),
    );
  }
}

@riverpod
class _GraphPageController extends _$GraphPageController {
  final Map<String, ChartSeriesController> _seriesControllers = {};
  final Map<String, List<TimeSeriesEntry>> _dataPoints = {};

  bool _tooltipActive = false;

  DateTime _last = DateTime(1990);

  BottomSheetService get _bottomSheetService => ref.read(bottomSheetServiceProvider);

  @override
  (double maxTemperature, List<CartesianSeries> series) build(String machineUUID) {
    // For now we DO not directly watch since this is somewhat trickery as we use UI controllers from SF charts
    // To sync new data via ref.listen to the SFChart controllers!
    final config = ref.read(printerProvider(machineUUID).selectRequireValue((printer) => printer.configFile));
    final tempStores = ref.read(temperatureStoresProvider(machineUUID).requireValue());

    ref.listen(
      temperatureStoresProvider(machineUUID).requireValue(),
      _syncStoreDataToChart,
    );
    Map<String, bool> initialSeriesVisibility = {};
    for (var key in tempStores.keys) {
      final tempSettingKey = CompositeKey.keyWithStrings(UtilityKeys.graphSettings, [key.$1.name, key.$2]);

      initialSeriesVisibility[temperatureSeriesKey(key)] = ref.read(boolSettingProvider(tempSettingKey, true));
      ref.listen(
        boolSettingProvider(tempSettingKey, true),
        (prev, next) => updateSeriesVisibility(key, next),
      );

      if (key.$1.isHeater) {
        final targetSettingKey = CompositeKey.keyWithString(tempSettingKey, 'target');
        initialSeriesVisibility[targetSeriesKey(key)] = ref.read(boolSettingProvider(targetSettingKey, true));
        ref.listen(
          boolSettingProvider(targetSettingKey, true),
          (prev, next) => updateSeriesVisibility(key, next, true),
        );
      }
    }

    final maxTemp = config.extruders.values.map((e) => e.maxTemp).maxOrNull ?? 300;
    return (maxTemp, _createSensorSeries(tempStores, initialSeriesVisibility));
  }

  void updateTooltip(bool active) {
    _tooltipActive = active;
  }

  void updateSeriesVisibility((ConfigFileObjectIdentifiers, String) ctrlKey, bool value, [bool target = false]) {
    final key = target ? targetSeriesKey(ctrlKey) : temperatureSeriesKey(ctrlKey);
    _seriesControllers[key]?.isVisible = value;
  }

  void openFilterSheet() => _bottomSheetService.show(BottomSheetConfig(
        type: SheetType.graphSettings,
        isScrollControlled: true,
        data: machineUUID,
      ));

  String temperatureSeriesKey((ConfigFileObjectIdentifiers, String) entry) => '${entry.$1.name} ${entry.$2}';

  String targetSeriesKey((ConfigFileObjectIdentifiers, String) entry) => '${entry.$1.name} ${entry.$2}-target';

  List<CartesianSeries> _createSensorSeries(TemperatureStore stores, Map<String, bool> initialSeriesVisibility) {
    List<CartesianSeries> output = [];
    var firstOrNull = stores.entries.firstOrNull;
    if (firstOrNull?.value.lastOrNull != null) {
      _last = firstOrNull!.value.lastOrNull!.time;
    }

    var i = 0;
    for (var store in stores.entries) {
      final (kind, objectName) = store.key;
      final tempKey = temperatureSeriesKey(store.key);
      final series = store.value;

      // We copy the series from the store to our own map
      final seriesPoints = series.toList();
      _dataPoints[tempKey] = seriesPoints;

      final seriesColor = indexToColor(i++);
      var ls = LineSeries<TimeSeriesEntry, DateTime>(
        initialIsVisible: initialSeriesVisibility[tempKey] != false,
        animationDuration: 100,
        color: seriesColor.$1,
        width: 1,
        name: '${objectName.capitalize} temperature',
        // color: themeData.colorScheme.colorsForEntry(index).$1,
        dataSource: seriesPoints,
        xValueMapper: (point, _) => point.time,
        yValueMapper: (point, _) => (point as TemperatureSensorSeriesEntry).temperature,
        onRendererCreated: (ChartSeriesController controller) => _seriesControllers[tempKey] = controller,
      );

      output.add(ls);

      if (seriesPoints.firstOrNull is HeaterSeriesEntry) {
        final targetKey = targetSeriesKey(store.key);
        final as = StepAreaSeries(
          initialIsVisible: initialSeriesVisibility[targetKey] != false,
          animationDuration: 100,
          dashArray: [5, 50],
          color: seriesColor.$2,
          enableTrackball: false,
          // Prevents it from showing up in trackball!
          dataSource: seriesPoints,
          xValueMapper: (point, _) => point.time,
          yValueMapper: (point, _) => (point as HeaterSeriesEntry).target.let((it) => it.unless(it == 0)),
          onRendererCreated: (ChartSeriesController controller) => _seriesControllers[targetKey] = controller,
        );

        output.add(as);
      }
    }

    return output;
  }

  void _syncStoreDataToChart(TemperatureStore? _, TemperatureStore allStores) {
    if (_tooltipActive || allStores.isEmpty) {
      // This makes sure we dont update while user is interacting with the chart to prevent flickering
      return;
    }

    final latestTimestamp = allStores.entries.first.value.lastOrNull?.time;
    if (latestTimestamp == null || latestTimestamp.isBefore(_last)) return;

    // aprox how many entries we need to add
    final entriesToAdd = latestTimestamp.difference(_last).inSeconds ?? 0;
    if (entriesToAdd == 0) return;

    // We need to add them now
    for (var entry in allStores.entries) {
      final series = entry.value;
      final tempKey = temperatureSeriesKey(entry.key);
      final targetKey = targetSeriesKey(entry.key);

      // Efficiently find new data points from the end
      final toAdd = <TemperatureSensorSeriesEntry>[];
      for (var i = series.length - 1; i >= 0; i--) {
        final point = series.elementAtOrNull(i);
        if (point?.time.isAfter(_last) != true) break;
        toAdd.insert(0, point!);
      }

      final dataSeries = _dataPoints[tempKey];
      if (toAdd.isEmpty || dataSeries == null) continue;

      int removed = 0;
      if ((dataSeries.length + toAdd.length) > TemperatureStoreService.maxStoreSize) {
        // Calc how many we need to remove to make space for the new ones
        final toRemove = (dataSeries.length + toAdd.length) - TemperatureStoreService.maxStoreSize;
        dataSeries.removeRange(0, toRemove);
        removed = toRemove;
      }
      int lenAfterRemoval = dataSeries.length;
      dataSeries.addAll(toAdd);

      _seriesControllers[tempKey]?.updateDataSource(
        addedDataIndexes: List.generate(toAdd.length, (index) => lenAfterRemoval + index),
        removedDataIndexes: List.generate(removed, (index) => index),
      );

      _seriesControllers[targetKey]?.updateDataSource(
        addedDataIndexes: List.generate(toAdd.length, (index) => lenAfterRemoval + index),
        removedDataIndexes: List.generate(removed, (index) => index),
      );
    }

    _last = latestTimestamp;
  }
}
