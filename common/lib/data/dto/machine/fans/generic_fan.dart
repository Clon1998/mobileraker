/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_double_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../config/config_file_object_identifiers_enum.dart';
import 'named_fan.dart';

part 'generic_fan.freezed.dart';
part 'generic_fan.g.dart';

@freezed
class GenericFan extends NamedFan with _$GenericFan {
  const GenericFan._();
  @StringDoubleConverter()
  const factory GenericFan({
    required String name,
    @Default(0) double speed,
    double? rpm,
  }) = _GenericFan;

  factory GenericFan.fromJson(Map<String, dynamic> json, [String? name]) =>
      _$GenericFanFromJson(name != null ? {...json, 'name': name} : json);

  factory GenericFan.partialUpdate(
      GenericFan current, Map<String, dynamic> partialJson) {
    var mergedJson = {...current.toJson(), ...partialJson};
    return GenericFan.fromJson(mergedJson);
  }

  @override
  ConfigFileObjectIdentifiers get kind => ConfigFileObjectIdentifiers.fan_generic;
}
