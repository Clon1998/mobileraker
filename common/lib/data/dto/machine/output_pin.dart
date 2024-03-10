/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'output_pin.freezed.dart';
part 'output_pin.g.dart';

@freezed
class OutputPin with _$OutputPin {
  const OutputPin._();
  const factory OutputPin({
    required String name,
    @Default(0.0) double value,
  }) = _OutputPin;

  factory OutputPin.fromJson(Map<String, dynamic> json, [String? name]) =>
      _$OutputPinFromJson(name != null ? {...json, 'name': name} : json);

  factory OutputPin.partialUpdate(
      OutputPin current, Map<String, dynamic> partialJson) {
    var mergedJson = {...current.toJson(), ...partialJson};
    return OutputPin.fromJson(mergedJson);
  }

  String get configName => name.toLowerCase();
}
