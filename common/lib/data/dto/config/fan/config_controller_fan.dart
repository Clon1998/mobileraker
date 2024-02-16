/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/integer_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'config_fan.dart';

part 'config_controller_fan.freezed.dart';
part 'config_controller_fan.g.dart';

@freezed
class ConfigControllerFan extends ConfigFan with _$ConfigControllerFan {
  const ConfigControllerFan._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ConfigControllerFan({
    required String name,
    required String pin,
    @Default(1) double maxPower,
    @Default(0) double shutdownSpeed,
    @Default(0.010) double cycleTime,
    @Default(false) bool hardwarePwm,
    @Default(0.100) double kickStartTime,
    @Default(0) double offBelow,
    String? tachometerPin,
    @IntegerConverter() @Default(2) int? tachometerPpr,
    @Default(0.0015) double? tachometerPollInterval,
    String? enablePin,
    @Default(1) double fanSpeed,
    @IntegerConverter() @Default(30) int idleTimeout,
    @Default(1.0) double idleSpeed,
    @Default([]) List<String> heater,
    @Default([]) List<String> stepper,
  }) = _ConfigControllerFan;

  factory ConfigControllerFan.fromJson(String name, Map<String, dynamic> json) =>
      _$ConfigControllerFanFromJson({...json, 'name': name});
}
