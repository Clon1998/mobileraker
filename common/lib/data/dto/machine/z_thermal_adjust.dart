/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/sensor_mixin.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../util/json_util.dart';

part 'z_thermal_adjust.freezed.dart';
part 'z_thermal_adjust.g.dart';

// z_thermal_adjust
// {
// 'temperature': self.smoothed_temp,
// 'measured_min_temp': round(self.measured_min, 2),
// 'measured_max_temp': round(self.measured_max, 2),
// 'current_z_adjust': self.z_adjust_mm,
// 'z_adjust_ref_temperature': self.ref_temperature,
// 'enabled': self.adjust_enable
// }

@freezed
class ZThermalAdjust with _$ZThermalAdjust, SensorMixin {
  const ZThermalAdjust._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ZThermalAdjust({
    @Default(false) bool enabled,
    @Default(0) double temperature,
    @Default(0) double measuredMinTemp,
    @Default(0) double measuredMaxTemp,
    @Default(0) double currentZAdjust,
    @Default(0) double zAdjustRefTemperature,
    @JsonKey(name: 'temperatures') List<double>? temperatureHistory,
    required DateTime lastHistory,
  }) = _ZThermalAdjust;

  factory ZThermalAdjust.fromJson(Map<String, dynamic> json) => _$ZThermalAdjustFromJson(json);

  factory ZThermalAdjust.partialUpdate(ZThermalAdjust current, Map<String, dynamic> partialJson) {
    var mergedJson = {...current.toJson(), ...partialJson};

    // Ill just put the tempCache here because I am lazy.. kinda sucks but who cares
    // Update temp cache for graphs!
    DateTime now = DateTime.now();

    if (now.difference(current.lastHistory).inSeconds >= 1) {
      mergedJson = {
        ...mergedJson,
        'temperatures': updateHistoryListInJson(mergedJson, 'temperatures', 'temperature'),
        'last_history': now.toIso8601String()
      };
    }

    return ZThermalAdjust.fromJson(mergedJson);
  }

  @override
  String get name => 'z_thermal_adjust';
}
