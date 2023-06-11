/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/data/dto/machine/heaters/heater_mixin.dart';
import 'package:mobileraker/util/json_util.dart';

part 'heater_bed.freezed.dart';
part 'heater_bed.g.dart';

@freezed
class HeaterBed with _$HeaterBed, HeaterMixin {
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

  String get name => 'heater_bed';
}
