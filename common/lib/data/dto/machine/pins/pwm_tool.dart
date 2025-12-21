/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_double_converter.dart';
import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
import 'package:common/data/dto/machine/pins/pin.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pwm_tool.freezed.dart';
part 'pwm_tool.g.dart';

@freezed
class PwmTool extends Pin with _$PwmTool {
  const PwmTool._();

  @StringDoubleConverter()
  const factory PwmTool({required String name, @Default(0.0) double value}) = _PwmTool;

  factory PwmTool.fromJson(Map<String, dynamic> json, [String? name]) =>
      _$PwmToolFromJson(name != null ? {...json, 'name': name} : json);

  factory PwmTool.partialUpdate(PwmTool current, Map<String, dynamic> partialJson) {
    var mergedJson = {...current.toJson(), ...partialJson};
    return PwmTool.fromJson(mergedJson);
  }

  String get configName => name.toLowerCase();

  @override
  ConfigFileObjectIdentifiers get kind => ConfigFileObjectIdentifiers.pwm_tool;
}
