/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../util/json_util.dart';
import 'sensor_mixin.dart';

part 'temperature_sensor.freezed.dart';
part 'temperature_sensor.g.dart';

@freezed
class TemperatureSensor with _$TemperatureSensor, SensorMixin {
  const TemperatureSensor._();

  const factory TemperatureSensor({
    required String name,
    @Default(0.0) double temperature,
    @JsonKey(name: 'measured_min_temp') @Default(0.0) double measuredMinTemp,
    @JsonKey(name: 'measured_max_temp') @Default(0.0) double measuredMaxTemp,
    @JsonKey(name: 'temperatures') List<double>? temperatureHistory,
    required DateTime lastHistory,
  }) = _TemperatureSensor;

  factory TemperatureSensor.fromJson(Map<String, dynamic> json,
          [String? name]) =>
      _$TemperatureSensorFromJson(
          name != null ? {...json, 'name': name} : json);

  factory TemperatureSensor.partialUpdate(
      TemperatureSensor current, Map<String, dynamic> partialJson) {
    var mergedJson = {...current.toJson(), ...partialJson};

    DateTime now = DateTime.now();
    if (now.difference(current.lastHistory).inSeconds >= 1) {
      mergedJson = {
        ...mergedJson,
        'temperatures':
            updateHistoryListInJson(mergedJson, 'temperatures', 'temperature'),
        'lastHistory': now.toIso8601String()
      };
    }

    return TemperatureSensor.fromJson(mergedJson);
  }
}
