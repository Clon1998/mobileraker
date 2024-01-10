/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'config_heater_generic.freezed.dart';
part 'config_heater_generic.g.dart';

// "control": "pid",

// heater_generic loool_heater": {
// "control": "pid",
// "pullup_resistor": 4700,
// "sensor_pin": "PF3",
// "heater_pin": "PD13",
// "max_power": 0.6,
// "sensor_type": "NTC 100K MGB18-104F39050L32",
// "inline_resistor": 0,
// "smooth_time": 1,
// "pwm_cycle_time": 0.1,
// "min_temp": 15,
// "min_extrude_temp": 170,
// "max_temp": 120

// "pid_ki": 1.395,
// "pid_kp": 40.598,
// "pid_kd": 295.352
// },

@freezed
class ConfigHeaterGeneric with _$ConfigHeaterGeneric {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ConfigHeaterGeneric({
    required String name,
    required String control,
    required String heaterPin,
    String? sensorPin, // BME280 has no sensor pin since it uses I2C
    required String sensorType,
    required double maxPower,
    required double maxTemp,
    required double minTemp,
  }) = _ConfigHeaterGeneric;

  factory ConfigHeaterGeneric.fromJson(String name, Map<String, dynamic> json) =>
      _$ConfigHeaterGenericFromJson({...json, 'name': name});
}
