/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_double_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../config/config_file_object_identifiers_enum.dart';
import '../temperature_sensor_mixin.dart';
import 'named_fan.dart';

part 'temperature_fan.freezed.dart';
part 'temperature_fan.g.dart';

//     "temperature_fan Case": {
// "speed": 0,
// "rpm": null,
// "temperature": 41.27,
// "target": 55
// }

@freezed
class TemperatureFan extends NamedFan with _$TemperatureFan, TemperatureSensorMixin {
  const TemperatureFan._();

  @StringDoubleConverter()
  const factory TemperatureFan(
      {required String name,
      @Default(0) double speed,
      double? rpm,
      @Default(0) double temperature,
      @Default(0) double target,
  }) = _TemperatureFan;

  factory TemperatureFan.fromJson(Map<String, dynamic> json, [String? name]) =>
      _$TemperatureFanFromJson(name != null ? {...json, 'name': name} : json);

  factory TemperatureFan.partialUpdate(TemperatureFan current, Map<String, dynamic> partialJson) =>
      TemperatureFan.fromJson({...current.toJson(), ...partialJson});

  @override
  ConfigFileObjectIdentifiers get kind => ConfigFileObjectIdentifiers.temperature_fan;
}
