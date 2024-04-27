/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../util/json_util.dart';
import '../sensor_mixin.dart';
import 'heater_mixin.dart';

part 'generic_heater.freezed.dart';
part 'generic_heater.g.dart';

@freezed
class GenericHeater with _$GenericHeater, SensorMixin, HeaterMixin {
  const GenericHeater._();

  const factory GenericHeater({
    required String name,
    @Default(0) double temperature,
    @Default(0) double target,
    @Default(0) double power,
    @JsonKey(name: 'temperatures') List<double>? temperatureHistory,
    @JsonKey(name: 'targets') List<double>? targetHistory,
    @JsonKey(name: 'powers') List<double>? powerHistory,
    required DateTime lastHistory,
  }) = _GenericHeater;

  factory GenericHeater.fromJson(Map<String, dynamic> json, [String? name]) =>
      _$GenericHeaterFromJson(name != null ? {...json, 'name': name} : json);

  factory GenericHeater.partialUpdate(GenericHeater current, Map<String, dynamic> partialJson) {
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
        'powers': updateHistoryListInJson(mergedJson, 'powers', 'power'),
        'lastHistory': now.toIso8601String()
      };
    }

    return GenericHeater.fromJson(mergedJson);
  }
}
