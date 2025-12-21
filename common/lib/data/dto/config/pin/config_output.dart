/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_double_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import './config_pin.dart';

part 'config_output.freezed.dart';
part 'config_output.g.dart';

@freezed
class ConfigOutput extends ConfigPin with _$ConfigOutput {
  @StringDoubleConverter()
  const factory ConfigOutput({
    required String name,
    @Default(1) double scale,
    @Default(false) bool pwm,
  }) = _ConfigOutput;

  factory ConfigOutput.fromJson(String name, Map<String, dynamic> json) =>
      _$ConfigOutputFromJson({'name': name, ...json});
}
