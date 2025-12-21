/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_double_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import './config_pin.dart';

part 'config_pwm_tool.freezed.dart';
part 'config_pwm_tool.g.dart';

@freezed
class ConfigPwmTool extends ConfigPin with _$ConfigPwmTool {

  @StringDoubleConverter()
  const factory ConfigPwmTool({
    required String name,
    @Default(1) double scale,
    @Default(false) bool pwm,
  }) = _ConfigPwmTool;

  factory ConfigPwmTool.fromJson(String name, Map<String, dynamic> json) =>
      _$ConfigPwmToolFromJson({'name': name, ...json});
}
