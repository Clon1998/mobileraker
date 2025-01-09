/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'config_gcode_macro_param.freezed.dart';
part 'config_gcode_macro_param.g.dart';

@freezed
class ConfigGcodeMacroParam with _$ConfigGcodeMacroParam {
  const factory ConfigGcodeMacroParam({
    final String? type,
    final String? defaultValue,
  }) = _ConfigGcodeMacroParam;

  factory ConfigGcodeMacroParam.fromJson(Map<String, dynamic> json) => _$ConfigGcodeMacroParamFromJson(json);
}
