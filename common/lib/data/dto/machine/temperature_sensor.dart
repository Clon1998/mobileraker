/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_double_converter.dart';
import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'temperature_sensor_mixin.dart';

part 'temperature_sensor.freezed.dart';
part 'temperature_sensor.g.dart';

@freezed
class TemperatureSensor with _$TemperatureSensor, TemperatureSensorMixin {
  const TemperatureSensor._();

  @StringDoubleConverter()
  const factory TemperatureSensor({
    required String name,
    @Default(0.0) double temperature,
    @JsonKey(name: 'measured_min_temp') @Default(0.0) double measuredMinTemp,
    @JsonKey(name: 'measured_max_temp') @Default(0.0) double measuredMaxTemp,
  }) = _TemperatureSensor;

  factory TemperatureSensor.fromJson(Map<String, dynamic> json, [String? name]) =>
      _$TemperatureSensorFromJson(name != null ? {...json, 'name': name} : json);

  factory TemperatureSensor.partialUpdate(TemperatureSensor current, Map<String, dynamic> partialJson) =>
      TemperatureSensor.fromJson({...current.toJson(), ...partialJson});

  @override
  ConfigFileObjectIdentifiers get kind => ConfigFileObjectIdentifiers.temperature_sensor;
}
