/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_double_converter.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'config_heater_bed.freezed.dart';
part 'config_heater_bed.g.dart';

@freezed
class ConfigHeaterBed with _$ConfigHeaterBed {
  @StringDoubleConverter()
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ConfigHeaterBed({
    required String heaterPin,
    required String sensorType,
    String? sensorPin,
    required String control,
    required double minTemp,
    required double maxTemp,
    @Default(1) double maxPower,
  }) = _ConfigHeaterBed;

  factory ConfigHeaterBed.fromJson(Map<String, dynamic> json) => _$ConfigHeaterBedFromJson(json);
}
