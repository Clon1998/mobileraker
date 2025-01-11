/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../util/json_util.dart';
import '../temperature_sensor_mixin.dart';
import 'heater_mixin.dart';

part 'heater_bed.freezed.dart';
part 'heater_bed.g.dart';

@freezed
class HeaterBed with _$HeaterBed, TemperatureSensorMixin, HeaterMixin {
  const HeaterBed._();

  const factory HeaterBed({
    @Default(0) double temperature,
    @Default(0) double target,
    @Default(0) double power,
    @JsonKey(name: 'temperatures') List<double>? temperatureHistory,
    @JsonKey(name: 'targets') List<double>? targetHistory,
    @JsonKey(name: 'powers') List<double>? powerHistory,
    required DateTime lastHistory,
  }) = _HeaterBed;

  factory HeaterBed.fromJson(Map<String, dynamic> json) =>
      _$HeaterBedFromJson(json);

  factory HeaterBed.partialUpdate(HeaterBed? current, Map<String, dynamic> partialJson) {
    HeaterBed old = current ?? HeaterBed(lastHistory: DateTime(1990));

    var mergedJson = {...old.toJson(), ...partialJson};
    // Ill just put the tempCache here because I am lazy.. kinda sucks but who cares
    // Update temp cache for graphs!
    DateTime now = DateTime.now();
    if (now.difference(old.lastHistory).inSeconds >= 1) {
      mergedJson = {
        ...mergedJson,
        'temperatures':
        updateHistoryListInJson(mergedJson, 'temperatures', 'temperature'),
        'targets': updateHistoryListInJson(mergedJson, 'targets', 'target'),
        'powers': updateHistoryListInJson(mergedJson, 'powers', 'power'),
        'lastHistory': now.toIso8601String()
      };
    }

    return HeaterBed.fromJson(mergedJson);
  }

  @override
  String get name => 'heater_bed';

  @override
  ConfigFileObjectIdentifiers get kind => ConfigFileObjectIdentifiers.heater_bed;
}
