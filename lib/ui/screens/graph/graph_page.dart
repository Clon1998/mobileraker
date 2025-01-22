/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
import 'package:common/data/model/moonraker_db/settings/reordable_element.dart';
import 'package:common/data/model/time_series_entry.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/moonraker/temperature_store_service.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

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

    final tempStores = ref.watch(temperatureStoresProvider(machineUUID).select((value) => value.hasValue));

    if (!tempStores) {
      return Center(child: CircularProgressIndicator());
    }

    return _GraphPage(machineUUID: machineUUID);
  }
}

class _GraphPage extends StatefulHookConsumerWidget {
  const _GraphPage({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  ConsumerState<_GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends ConsumerState<_GraphPage> {
// Controllers for each series
  final Map<String, ChartSeriesController> _temperatureControllers = {};

// Data sources for live updates
  final Map<String, List<TimeSeriesEntry>> _dataPoints = {};

  late TrackballBehavior _trackballBehavior;

  int? activeIndex;

  DateTime _last = DateTime(1990);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.read(printerProvider(widget.machineUUID).selectRequireValue((printer) => printer.configFile));
    final tempStores = ref.read(temperatureStoresProvider(widget.machineUUID).requireValue());

    ref.listen(
      temperatureStoresProvider(widget.machineUUID).requireValue(),
      (_, allStores) {
        if (activeIndex != null || allStores.isEmpty) {
          // This makes sure we dont update while user is interacting with the chart to prevent flickering
          return;
        }

        var aStoreEntry = allStores.entries.first;
        // The up-2-date timestamp from the store
        final latestTimestamp = aStoreEntry.value.lastOrNull?.time;

        // aprox how many entries we need to add
        final entriesToAdd = latestTimestamp?.difference(_last).inSeconds ?? 0;
        if (entriesToAdd == 0) return;

        // We need to add them now
        for (var entry in allStores.entries) {
          final (kind, objectName) = entry.key;
          final series = entry.value;
          final key = '${kind.name} $objectName';

          final dataSeries = _dataPoints[key];

          final toAdd = <TemperatureSensorSeriesEntry>[];

          // We have an aprox, but since we check for after anyway we can just walk from the back
          for (var i = series.length - 1; i >= 0; i--) {
            final entry = series.elementAtOrNull(i);
            if (entry?.time.isAfter(_last) != true) break;
            toAdd.insert(0, entry!);
          }
          // final toAdd = series.sublist(totalStoreLen - entriesToAdd).where((e) => e.time.isAfter(_last));
          if (toAdd.isEmpty || dataSeries == null) {
            continue;
          }

          int removed = 0;
          if ((dataSeries.length + toAdd.length) > TemperatureStoreService.maxStoreSize) {
            // Calc how many we need to remove to make space for the new ones
            final toRemove = (dataSeries.length + toAdd.length) - TemperatureStoreService.maxStoreSize;
            dataSeries.removeRange(0, toRemove);
            removed = toRemove;
          }
          int lenAfterRemoval = dataSeries.length;
          dataSeries.addAll(toAdd);

          // now at what indexed did we insert them?
          // Well from the NOW new Len - the added length -1

          _temperatureControllers[key]?.updateDataSource(
            addedDataIndexes: List.generate(toAdd.length, (index) => lenAfterRemoval + index),
            removedDataIndexes: List.generate(removed, (index) => index),
          );

          // If we have a target we need to inform it about the update too!
          _temperatureControllers['$key-target']?.updateDataSource(
            addedDataIndexes:
                // List.generate(toAdd.length, (index) => dataSeries.length - (index + addedOffset)).also((value) {
                List.generate(toAdd.length, (index) => lenAfterRemoval + index),
            removedDataIndexes: List.generate(removed, (index) => index),
          );
        }

        _last = latestTimestamp ?? _last;
      },
    );

    var maxTemp = config.extruders.values.map((e) => e.maxTemp).maxOrNull ?? 300;

    return Scaffold(
      appBar: AppBar(
        title: Text('GRAPHS-WIP'),
        actions: [
          // IconButton(
          //   onPressed: () {
          //     ref
          //         .read(bottomSheetServiceProvider)
          //         .show(BottomSheetConfig(type: SheetType.graphSettings, isScrollControlled: true));
          //   },
          //   icon: Icon(Icons.legend_toggle),
          // ),
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
          onChartTouchInteractionDown: (ChartTouchInteractionArgs args) {
            logger.i('Chart touch interaction down');
            activeIndex = 0;
          },
          onChartTouchInteractionUp: (ChartTouchInteractionArgs args) {
            logger.i('Chart touch interaction up');
            activeIndex = null;
          },
          primaryXAxis: DateTimeAxis(name: 'Time'),
          primaryYAxis: NumericAxis(
            title: AxisTitle(text: 'Temperature [°C]'),
            name: 'Temperature [°C]',
            minimum: 0,
            maximum: maxTemp,
          ),
          series: createSensorSeries(tempStores),
        ),
      ),
    );
  }

  List<CartesianSeries> createSensorSeries(Map<(ConfigFileObjectIdentifiers, String), List<TimeSeriesEntry>> stores) {
    logger.e("!!!!!!!!!! CREATING SENSOR SERIES !!!!!!!!!!");

    List<ReordableElement> ordering =
        ref.watch(machineSettingsProvider(widget.machineUUID).selectRequireValue((value) => value.tempOrdering));

    List<CartesianSeries> output = [];
    var firstOrNull = stores.entries.firstOrNull;
    if (firstOrNull?.value.lastOrNull != null) {
      _last = firstOrNull!.value.lastOrNull!.time;
    }

    var sorted = stores.entries.sorted((a, b) {
      var aIndex = ordering.indexWhere((element) => element.name == a.key.$2 && element.kind == a.key.$1);
      var bIndex = ordering.indexWhere((element) => element.name == b.key.$2 && element.kind == b.key.$1);

      if (aIndex == -1) aIndex = output.length;
      if (bIndex == -1) bIndex = output.length;

      return aIndex.compareTo(bIndex);
    });

    final colorScheme = ColorScheme.of(context);
    var i = 0;
    for (var sensor in sorted) {
      final (kind, objectName) = sensor.key;
      final timeSeries = sensor.value;

      var colorsForEntry = colorScheme.colorsForEntry(i++);

      logger.i('Creating series for ${sensor.key}');

      // final (sensorBarColor, sensorAreaColor) = colorScheme.colorsForEntry(idx++);

      final key = '${kind.name} $objectName';
      var ds = timeSeries.toList();
      _dataPoints[key] = ds;

      var ls = LineSeries<TimeSeriesEntry, DateTime>(
        animationDuration: 100,
        color: colorsForEntry.$1,
        width: 1,
        name: '${objectName.capitalize} temperature',
        // color: themeData.colorScheme.colorsForEntry(index).$1,
        dataSource: ds,
        xValueMapper: (point, _) => point.time,
        yValueMapper: (point, _) => (point as TemperatureSensorSeriesEntry).temperature,
        onRendererCreated: (ChartSeriesController controller) {
          logger.i('Got controller for ${key}');

          _temperatureControllers[key] = controller;
        },
      );

      output.add(ls);

      bool isHeater = ds.firstOrNull is HeaterSeriesEntry;

      if (isHeater) {
        final barSeries = StepAreaSeries(
          animationDuration: 100,

          dashArray: [5, 50],
          color: colorsForEntry.$2,
          name: '${objectName.capitalize} target',
          enableTrackball: false,
          // Prevents it from showing up in trackball!
          dataSource: ds,
          xValueMapper: (point, _) => point.time,
          yValueMapper: (point, _) => (point as HeaterSeriesEntry).target.let((it) => it.unless(it == 0)),
          onRendererCreated: (ChartSeriesController controller) {
            _temperatureControllers['$key-target'] = controller;
          },
        );

        output.add(barSeries);
      }

      // var ls = LineSeries<TimeSeriesEntry, DateTime>(
      //   animationDuration: 100,
      //   name: '${objectName.capitalize} temperature',
      //   // color: themeData.colorScheme.colorsForEntry(index).$1,
      //   dataSource: ds,
      //   xValueMapper: (point, _) => point.time,
      //   yValueMapper: (point, _) => (point as TemperatureSensorSeriesEntry).temperature,
      //   onRendererCreated: (ChartSeriesController controller) {
      //     logger.i('Got controller for ${key}');
      //
      //     _temperatureControllers[key] = controller;
      //   },
      // );
      //
      // output.add(ls);
    }
    logger.w('GOT SENSOR OUTPUT: ${output.length}');

    return output;

    return [];
  }
}

extension _BarColor on ColorScheme {
  (Color barColor, Color belowColor) colorsForEntry(int i) {
    final materialColors = [
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.lime,
      Colors.indigo,
    ];

    if (i < materialColors.length) {
      final color = materialColors[i];
      return (color, color.withOpacity(0.2));
    }

    // Fallback method
    // Fallback method using HSL hue ring
    final hue = (i * 37) % 360; // Use a prime number to distribute colors more evenly
    final color = HSLColor.fromAHSL(
            1.0,
            hue.toDouble(),
            0.7, // Consistent saturation
            0.5 // Consistent lightness
            )
        .toColor();

    return (color, color.withOpacity(0.2));
  }
}

/**
    ref.listen(
    temperatureStoresProvider(widget.machineUUID).requireValue(),
    (_, allStores) {
    if (activeIndex != null || allStores.isEmpty) {
    // This makes sure we dont update while user is interacting with the chart to prevent flickering
    return;
    }

    var aStoreEntry = allStores.entries.first;
    // The up-2-date timestamp from the store
    final latestTimestamp = aStoreEntry.value.lastOrNull?.time;

    // aprox how many entries we need to add
    final entriesToAdd = latestTimestamp?.difference(_last).inSeconds ?? 0;
    logger.i('Entries to add: $entriesToAdd');

    // We need to add them now
    final totalStoreLen = aStoreEntry.value.length;
    for (var entry in allStores.entries) {
    final (kind, objectName) = entry.key;
    final series = entry.value;
    final key = '${kind.name} $objectName';

    final dataSeries = _dataPoints[key];


    final toAdd = series.sublist(totalStoreLen - entriesToAdd).where((e) => e.time.isAfter(_last));
    if (toAdd.isEmpty || dataSeries == null) {
    continue;
    }

    logger.i('Current DS.length ${dataSeries?.length} for $key');


    bool removed = false;
    if ((dataSeries.length+toAdd.length) > TemperatureStoreService.maxStoreSize) {
    // Calc how many we need to remove to make space for the new ones
    final toRemove = (dataSeries.length + toAdd.length) - TemperatureStoreService.maxStoreSize;
    dataSeries.removeRange(0, toRemove);
    logger.i('Removing $toRemove entries from $key');
    removed = true;
    }

    final dsIndex = dataSeries.length;
    dataSeries.addAll(toAdd);
    logger.i('Adding dsIndex: $dsIndex, toAdd: ${toAdd.length} for $key');


    _temperatureControllers[key]?.updateDataSource(
    // addedDataIndexes: List.generate(toAdd.length, (index) => dsIndex + index).also((value) => logger.i('ADDEDINDEXES: $value')),
    addedDataIndex: dsIndex-1,
    removedDataIndex: removed? 0: -1,
    // removedDataIndexes: List.generate(toAdd.length, (index) => index),
    // removedDataIndex: removeFirst ? 0 : -1,
    );
    }

    _last = latestTimestamp ?? _last;
    },
    );
 */

// VERSION WHERE WE JUST ADD THE LATEST...

/**
    ref.listen(
    temperatureStoresProvider(widget.machineUUID).requireValue(),
    (_, allStores) {
    if (activeIndex != null || allStores.isEmpty) {
    // This makes sure we dont update while user is interacting with the chart to prevent flickering
    return;
    }

    for (var entry in allStores.entries) {
    final (kind, objectName) = entry.key;
    final series = entry.value;
    final key = '${kind.name} $objectName';

    final dataSeries = _dataPoints[key];

    final toAdd = series.lastOrNull;

    if (dataSeries == null || toAdd == null) continue;


    bool removed = false;
    if (dataSeries.length > TemperatureStoreService.maxStoreSize) {
    dataSeries.removeAt(0);
    removed = true;
    }
    dataSeries.add(toAdd);

    _temperatureControllers[key]?.updateDataSource(
    // addedDataIndexes: List.generate(toAdd.length, (index) => dsIndex + index).also((value) => logger.i('ADDEDINDEXES: $value')),
    addedDataIndex: dataSeries.length-1,
    removedDataIndex: removed? 0: -1,
    // removedDataIndexes: List.generate(toAdd.length, (index) => index),
    // removedDataIndex: removeFirst ? 0 : -1,
    );
    }
    },
    );
 */
