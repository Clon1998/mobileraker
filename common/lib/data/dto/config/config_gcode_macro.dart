/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import 'config_gcode_macro_param.dart';

part 'config_gcode_macro.freezed.dart';
part 'config_gcode_macro.g.dart';

@freezed
class ConfigGcodeMacro with _$ConfigGcodeMacro {
  const factory ConfigGcodeMacro({
    @JsonKey(name: 'name') required String macroName,
    required String gcode,
    String? description,
    @Default({})
    @JsonKey(readValue: _readValue, fromJson: _parseParams, includeToJson: false)
    Map<String, ConfigGcodeMacroParam> params,
  }) = _ConfigGcodeMacro;

  factory ConfigGcodeMacro.fromJson(String name, Map<String, dynamic> json) =>
      _$ConfigGcodeMacroFromJson({'name': name, ...json});
}

String? _readValue(Map json, String key) {
  final gcode = json['gcode'];
  if (gcode case String()) return gcode;
  return null;
}

Map<String, ConfigGcodeMacroParam> _parseParams(String gcode) {
  // Kindly taken from mainsail https://github.com/mainsail-crew/mainsail/blob/05e9e410a043fa5f2e2e461d34a35391f9982b84/src/plugins/helpers.ts#L202-L203
  final paramRegex = RegExp(
      "\\{%?.*?params\\.([A-Za-z_0-9]+)(?:\\|(int|string|double|float))?(?:\\|default\\('?\"?(.*?)\"?'?\\))?(?:\\|(int|string|double|float))?.*?%?\\}");

  Map<String, ConfigGcodeMacroParam> ret = {};

  // Process `params`
  for (var match in paramRegex.allMatches(gcode)) {
    final name = match.group(1);
    final type = match.group(2) ?? match.group(4);
    final def = match.group(3);

    if (name != null) {
      ret[name] = ConfigGcodeMacroParam(
        type: type,
        defaultValue: def,
      );
    }
  }

  return ret;
}
