/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'gcode_macro.freezed.dart';
part 'gcode_macro.g.dart';

@Freezed(toJson: false)
class GcodeMacro with _$GcodeMacro {
  const GcodeMacro._();

  const factory GcodeMacro({
    required String name,
    @JsonKey(readValue: readVars) @Default({}) Map<String, dynamic> vars,
  }) = _GcodeMacro;

  factory GcodeMacro.fromJson(Map<String, dynamic> json, [String? name]) =>
      _$GcodeMacroFromJson(name != null ? {...json, 'name': name} : json);

  factory GcodeMacro.partialUpdate(GcodeMacro current, Map<String, dynamic> partialJson) {
    var mergedJson = {...current.toJson(), ...partialJson};
    return GcodeMacro.fromJson(mergedJson);
  }

  bool get isVisible => !isHidden;

  bool get isHidden => name.startsWith('_');
}

Map<String, dynamic> readVars(Map input, String key) {
  Map<String, dynamic> vars = {};

  for (var entry in input.entries) {
    final key = entry.key;
    if (key is String && key != 'name') {
      vars[key] = entry.value;
    }
  }
  return vars;
}

/// This is a hack to get the toJson to work while still using freezed to generate the rest...
extension JsonMacro on GcodeMacro {
  Map<String, dynamic> toJson() => {
        'name': name,
        ...vars,
      };
}
