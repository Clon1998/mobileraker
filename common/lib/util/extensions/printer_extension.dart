/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/fans/temperature_fan.dart';
import 'package:common/data/dto/machine/printer.dart';
import 'package:common/data/dto/machine/temperature_sensor_mixin.dart';
import 'package:common/data/model/moonraker_db/settings/reordable_element.dart';

/// Extension methods for the [Printer] class to provide enhanced sensor management and filtering capabilities.
extension CombinedSensorExtension on Printer {
  /// Retrieves a consolidated list of all temperature-related sensors from the printer.
  ///
  /// This getter aggregates sensors from various printer components including:
  /// - Extruders
  /// - Heater bed (if present)
  /// - Generic heaters
  /// - Temperature sensors
  /// - Temperature-controlled fans
  /// - Z-axis thermal adjustment sensor (if present)
  ///
  /// Example:
  /// ```dart
  /// List<SensorMixin> allPrinterSensors = printer.allSensors;
  /// ```
  ///
  /// Returns a list of [TemperatureSensorMixin] objects representing all temperature sensors.
  List<TemperatureSensorMixin> get allTemperatureSensors => [
        ...extruders,
        if (heaterBed != null) heaterBed!,
        ...genericHeaters.values,
        ...temperatureSensors.values,
        ...fans.values.whereType<TemperatureFan>(),
        if (zThermalAdjust != null) zThermalAdjust!,
      ];

  /// Filters and sorts the printer's sensors based on a provided ordering configuration.
  ///
  /// This method does the following:
  /// 1. Retrieves all sensors using [allTemperatureSensors]
  /// 2. Filters out sensors with names starting with an underscore
  /// 3. Sorts sensors according to the provided [ordering]
  ///
  /// Parameters:
  /// - [ordering] A list of [ReordableElement] that defines the desired sensor order
  ///
  /// Example:
  /// ```dart
  /// List<ReordableElement> customOrdering = [...];
  /// List<SensorMixin> orderedSensors = printer.filteredAndSortedSensors(customOrdering);
  /// ```
  ///
  /// Returns a sorted and filtered list of [TemperatureSensorMixin] objects.
  List<TemperatureSensorMixin> filteredAndSortedSensors(List<ReordableElement> ordering) {
    return filterAndSortSensors(allTemperatureSensors, ordering);
  }

  List<TemperatureFan> get temperatureFans => fans.values.whereType<TemperatureFan>().toList();

  /// Static method to filter and sort a list of sensors based on a given ordering.
  ///
  /// This method provides a standalone way to filter and sort sensors without a [Printer] instance.
  ///
  /// Parameters:
  /// - [allSensors] The complete list of sensors to be processed
  /// - [ordering] A list of [ReordableElement] that defines the desired sensor order
  ///
  /// Process:
  /// 1. Filters out sensors with names starting with an underscore
  /// 2. Sorts sensors based on the provided [ordering]
  ///   - Sensors in the ordering list are placed first, in the specified order
  ///   - Sensors not in the ordering list are placed at the end
  ///
  /// Example:
  /// ```dart
  /// List<SensorMixin> sensors = [...];
  /// List<ReordableElement> customOrdering = [...];
  /// List<SensorMixin> processedSensors = CombinedSensorExtension.filterAndSortSensors(sensors, customOrdering);
  /// ```
  ///
  /// Returns a sorted and filtered list of [TemperatureSensorMixin] objects.
  static List<TemperatureSensorMixin> filterAndSortSensors(
      List<TemperatureSensorMixin> allSensors, List<ReordableElement> ordering) {
    var output = <TemperatureSensorMixin>[];
    // Filter out all sensors starting with an underscore
    for (var sensor in allSensors) {
      if (sensor.name.startsWith('_')) continue;
      output.add(sensor);
    }

    // Sort output by ordering, if ordering is not found it will be placed at the end
    output.sort((a, b) {
      var aIndex = ordering.indexWhere((element) => element.name == a.name && element.kind == a.kind);
      var bIndex = ordering.indexWhere((element) => element.name == b.name && element.kind == b.kind);

      if (aIndex == -1) aIndex = output.length;
      if (bIndex == -1) bIndex = output.length;

      return aIndex.compareTo(bIndex);
    });
    return output;
  }
}
