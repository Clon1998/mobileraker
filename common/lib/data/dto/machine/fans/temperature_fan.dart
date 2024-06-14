/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../util/json_util.dart';
import '../sensor_mixin.dart';
import 'named_fan.dart';

part 'temperature_fan.freezed.dart';
part 'temperature_fan.g.dart';

//     "temperature_fan Case": {
// "speed": 0,
// "rpm": null,
// "temperature": 41.27,
// "target": 55
// }

@freezed
class TemperatureFan extends NamedFan with _$TemperatureFan, SensorMixin {
  const TemperatureFan._();

  const factory TemperatureFan(
      {required String name,
      @Default(0) double speed,
      double? rpm,
      @Default(0) double temperature,
      @Default(0) double target,
      @JsonKey(name: 'temperatures') List<double>? temperatureHistory,
      @JsonKey(name: 'targets') List<double>? targetHistory,
      required DateTime lastHistory}) = _TemperatureFan;

  factory TemperatureFan.fromJson(Map<String, dynamic> json, [String? name]) =>
      _$TemperatureFanFromJson(name != null ? {...json, 'name': name} : json);

  factory TemperatureFan.partialUpdate(
      TemperatureFan current, Map<String, dynamic> partialJson) {
    var mergedJson = {...current.toJson(), ...partialJson};
    // Ill just put the tempCache here because I am lazy.. kinda sucks but who cares
    // Update temp cache for graphs!
    DateTime now = DateTime.now();
    if (now.difference(current.lastHistory).inSeconds >= 1) {
      mergedJson = {
        ...mergedJson,
        'temperatures':
            updateHistoryListInJson(mergedJson, 'temperatures', 'temperature'),
        'targets': updateHistoryListInJson(mergedJson, 'targets', 'target'),
        'lastHistory': now.toIso8601String()
      };
    }
    return TemperatureFan.fromJson(mergedJson);
  }
}
