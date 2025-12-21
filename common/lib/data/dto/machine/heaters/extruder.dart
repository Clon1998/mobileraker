/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_double_converter.dart';
import 'package:common/data/converters/string_integer_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../config/config_file_object_identifiers_enum.dart';
import '../temperature_sensor_mixin.dart';
import 'heater_mixin.dart';

part 'extruder.freezed.dart';
part 'extruder.g.dart';

@freezed
class Extruder with _$Extruder, TemperatureSensorMixin, HeaterMixin {
  static Extruder empty([int num = 0]) {
    return Extruder(num: num);
  }

  const Extruder._();

  @StringIntegerConverter()
  @StringDoubleConverter()
  const factory Extruder({
    required int num,
    @Default(0) double temperature,
    @Default(0) double target,
    @JsonKey(name: 'pressure_advance') @Default(0) double pressureAdvance,
    @JsonKey(name: 'smooth_time') @Default(0) double smoothTime,
    @Default(0) double power,
  }) = _Extruder;

  factory Extruder.fromJson(Map<String, dynamic> json) => _$ExtruderFromJson(json);

  factory Extruder.partialUpdate(Extruder current, Map<String, dynamic> partialJson) =>
      Extruder.fromJson({...current.toJson(), ...partialJson});

  @override
  String get name => 'extruder${this.num > 0 ? this.num : ''}';

  @override
  ConfigFileObjectIdentifiers get kind => ConfigFileObjectIdentifiers.extruder;
}
