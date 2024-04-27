/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../util/json_util.dart';
import '../sensor_mixin.dart';
import 'heater_mixin.dart';

part 'extruder.freezed.dart';
part 'extruder.g.dart';

@freezed
class Extruder with _$Extruder, SensorMixin, HeaterMixin {
  static Extruder empty([int num = 0]) {
    return Extruder(num: num, lastHistory: DateTime(1990));
  }

  const Extruder._();

  const factory Extruder({required int num,
    @Default(0) double temperature,
    @Default(0) double target,
    @JsonKey(name: 'pressure_advance') @Default(0) double pressureAdvance,
    @JsonKey(name: 'smooth_time') @Default(0) double smoothTime,
    @Default(0) double power,
    @JsonKey(name: 'temperatures') List<double>? temperatureHistory,
    @JsonKey(name: 'targets') List<double>? targetHistory,
    @JsonKey(name: 'powers') List<double>? powerHistory,
    required DateTime lastHistory}) = _Extruder;

  factory Extruder.fromJson(Map<String, dynamic> json) =>
      _$ExtruderFromJson(json);

  factory Extruder.partialUpdate(Extruder current,
      Map<String, dynamic> partialJson) {
    var mergedJson = {...current.toJson(), ...partialJson};
    // Ill just put the tempCache here because I am lazy.. kinda sucks but who cares
    // Update temp cache for graphs!
    DateTime now = DateTime.now();
    if (now
        .difference(current.lastHistory)
        .inSeconds >= 1) {
      mergedJson = {
        ...mergedJson,
        'temperatures':
        updateHistoryListInJson(mergedJson, 'temperatures', 'temperature'),
        'targets': updateHistoryListInJson(mergedJson, 'targets', 'target'),
        'powers': updateHistoryListInJson(mergedJson, 'powers', 'power'),
        'lastHistory': now.toIso8601String()
      };
    }

    return Extruder.fromJson(mergedJson);
  }

  @override
  String get name => 'extruder${this.num > 0 ? this.num : ''}';
}
