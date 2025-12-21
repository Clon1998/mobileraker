/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_double_converter.dart';
import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
import 'package:common/data/dto/machine/pins/pin.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'output_pin.freezed.dart';
part 'output_pin.g.dart';

@freezed
class OutputPin extends Pin with _$OutputPin {
  const OutputPin._();

  @StringDoubleConverter()
  const factory OutputPin({required String name, @Default(0.0) double value}) = _OutputPin;

  factory OutputPin.fromJson(Map<String, dynamic> json, [String? name]) =>
      _$OutputPinFromJson(name != null ? {...json, 'name': name} : json);

  factory OutputPin.partialUpdate(OutputPin current, Map<String, dynamic> partialJson) {
    var mergedJson = {...current.toJson(), ...partialJson};
    return OutputPin.fromJson(mergedJson);
  }

  @override
  ConfigFileObjectIdentifiers get kind => ConfigFileObjectIdentifiers.output_pin;
}
