/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_double_converter.dart';
import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../temperature_sensor_mixin.dart';
import 'heater_mixin.dart';

part 'generic_heater.freezed.dart';
part 'generic_heater.g.dart';

@freezed
class GenericHeater with _$GenericHeater, TemperatureSensorMixin, HeaterMixin {
  const GenericHeater._();

  @StringDoubleConverter()
  const factory GenericHeater({
    required String name,
    @Default(0) double temperature,
    @Default(0) double target,
    @Default(0) double power,
  }) = _GenericHeater;

  factory GenericHeater.fromJson(Map<String, dynamic> json, [String? name]) =>
      _$GenericHeaterFromJson(name != null ? {...json, 'name': name} : json);

  factory GenericHeater.partialUpdate(GenericHeater current, Map<String, dynamic> partialJson) =>
      GenericHeater.fromJson({...current.toJson(), ...partialJson});

  @override
  ConfigFileObjectIdentifiers get kind => ConfigFileObjectIdentifiers.heater_generic;
}
