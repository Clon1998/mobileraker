/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_double_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../config/config_file_object_identifiers_enum.dart';
import 'temperature_sensor_mixin.dart';

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
class ZThermalAdjust with _$ZThermalAdjust, TemperatureSensorMixin {
  const ZThermalAdjust._();

  @StringDoubleConverter()
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ZThermalAdjust({
    @Default(false) bool enabled,
    @Default(0) double temperature,
    @Default(0) double measuredMinTemp,
    @Default(0) double measuredMaxTemp,
    @Default(0) double currentZAdjust,
    @Default(0) double zAdjustRefTemperature,
  }) = _ZThermalAdjust;

  factory ZThermalAdjust.fromJson(Map<String, dynamic> json) => _$ZThermalAdjustFromJson(json);

  factory ZThermalAdjust.partialUpdate(ZThermalAdjust current, Map<String, dynamic> partialJson) =>
      ZThermalAdjust.fromJson({...current.toJson(), ...partialJson});

  @override
  String get name => 'z_thermal_adjust';

  @override
  ConfigFileObjectIdentifiers get kind => ConfigFileObjectIdentifiers.z_thermal_adjust;
}
