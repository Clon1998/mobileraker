/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/integer_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'config_fan.dart';

part 'config_print_cooling_fan.freezed.dart';
part 'config_print_cooling_fan.g.dart';

@freezed
class ConfigPrintCoolingFan extends ConfigFan with _$ConfigPrintCoolingFan {
  const ConfigPrintCoolingFan._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ConfigPrintCoolingFan({
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
  }) = _ConfigPrintCoolingFan;

  factory ConfigPrintCoolingFan.fromJson(Map<String, dynamic> json) =>
      _$ConfigPrintCoolingFanFromJson({...json});

  @override
  String get name => 'Print cooling fan';
}
