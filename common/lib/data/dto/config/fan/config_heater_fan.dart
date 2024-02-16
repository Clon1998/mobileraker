/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/integer_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'config_fan.dart';

part 'config_heater_fan.freezed.dart';
part 'config_heater_fan.g.dart';

@freezed
class ConfigHeaterFan extends ConfigFan with _$ConfigHeaterFan {
  const ConfigHeaterFan._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ConfigHeaterFan({
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
    @Default(50) double heaterTemp,
    @Default(1) double fanSpeed,
    required List<String> heater,
  }) = _ConfigHeaterFan;

  factory ConfigHeaterFan.fromJson(String name, Map<String, dynamic> json) =>
      _$ConfigHeaterFanFromJson({...json, 'name': name});
}
