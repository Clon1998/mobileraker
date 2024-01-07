/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/integer_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'config_fan.dart';

part 'config_temperature_fan.freezed.dart';
part 'config_temperature_fan.g.dart';

@freezed
class ConfigTemperatureFan extends ConfigFan with _$ConfigTemperatureFan {
  const ConfigTemperatureFan._();

  const factory ConfigTemperatureFan({
    required String name,
    required String pin,
    @JsonKey(name: 'max_power') @Default(1) double maxPower,
    @JsonKey(name: 'shutdown_speed') @Default(0) double shutdownSpeed,
    @JsonKey(name: 'cycle_time') @Default(0.010) double cycleTime,
    @JsonKey(name: 'hardware_pwm') @Default(false) bool hardwarePwm,
    @JsonKey(name: 'kick_start_time') @Default(0.100) double kickStartTime,
    @JsonKey(name: 'off_below') @Default(0) double offBelow,
    @JsonKey(name: 'tachometer_pin') String? tachometerPin,
    @IntegerConverter() @JsonKey(name: 'tachometer_ppr') @Default(2) int? tachometerPpr,
    @JsonKey(name: 'tachometer_poll_interval') @Default(0.0015) double? tachometerPollInterval,
    @JsonKey(name: 'enable_pin') String? enablePin,
    @JsonKey(name: 'min_temp') @Default(0) double minTemp,
    @JsonKey(name: 'max_temp') @Default(50) double maxTemp,
    @JsonKey(name: 'target_temp') @Default(40) double targetTemp,
    @JsonKey(name: 'max_speed') @Default(1) double maxSpeed,
    @JsonKey(name: 'min_speed') @Default(0.3) double minSpeed,
  }) = _ConfigTemperatureFan;

  factory ConfigTemperatureFan.fromJson(String name, Map<String, dynamic> json) =>
      _$ConfigTemperatureFanFromJson({...json, 'name': name});
}
