/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_double_converter.dart';
import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../temperature_sensor_mixin.dart';
import 'heater_mixin.dart';

part 'heater_bed.freezed.dart';
part 'heater_bed.g.dart';

@freezed
class HeaterBed with _$HeaterBed, TemperatureSensorMixin, HeaterMixin {
  const HeaterBed._();

  @StringDoubleConverter()
  const factory HeaterBed({
    @Default(0) double temperature,
    @Default(0) double target,
    @Default(0) double power,
  }) = _HeaterBed;

  factory HeaterBed.fromJson(Map<String, dynamic> json) =>
      _$HeaterBedFromJson(json);

  factory HeaterBed.partialUpdate(HeaterBed? current, Map<String, dynamic> partialJson) {
    HeaterBed old = current ?? HeaterBed();

    return HeaterBed.fromJson({...old.toJson(), ...partialJson});
  }

  @override
  String get name => 'heater_bed';

  @override
  ConfigFileObjectIdentifiers get kind => ConfigFileObjectIdentifiers.heater_bed;
}
