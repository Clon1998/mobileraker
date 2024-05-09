/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'config_gcode_macro.freezed.dart';
part 'config_gcode_macro.g.dart';

final RegExp paramsRegex = RegExp(r'params\.(\w+)(.*)', caseSensitive: false);

final RegExp defaultReg = RegExp(
    "\\|\\s*default\\s*\\(\\s*(([\"'])(?:\\\\.|[^\\2])*\\2|-?[0-9][^,)]*|(?:true|false))",
    caseSensitive: false);

Map<String, String> _parseParams(Map input, String key) {
  Map<String, String> paramsWithDefaults = {};
  String gcode = input['gcode'];
  for (RegExpMatch paramMatch in paramsRegex.allMatches(gcode)) {
    String? paramName = paramMatch.group(1);
    if (paramName == null) {
      continue;
    }

    String defaultMatchGrp = paramMatch.group(2) ?? '';
    RegExpMatch? defaultMatch = defaultReg.firstMatch(defaultMatchGrp);

    paramsWithDefaults[paramName] = defaultMatch?.group(1)?.trim() ?? '';
  }
  return paramsWithDefaults;
}

@freezed
class ConfigGcodeMacro with _$ConfigGcodeMacro {
  const factory ConfigGcodeMacro({
    @JsonKey(name: 'name') required String macroName,
    required String gcode,
    String? description,
    @Default({}) @JsonKey(readValue: _parseParams) Map<String, String> params,
  }) = _ConfigGcodeMacro;

  factory ConfigGcodeMacro.fromJson(String name, Map<String, dynamic> json) =>
      _$ConfigGcodeMacroFromJson({'name': name, ...json});
}
