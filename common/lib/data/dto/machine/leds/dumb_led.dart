/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../converters/pixel_converter.dart';
import '../../config/config_file_object_identifiers_enum.dart';
import 'led.dart';

part 'dumb_led.freezed.dart';
part 'dumb_led.g.dart';

@freezed
class DumbLed extends Led with _$DumbLed {
  const DumbLed._();

  const factory DumbLed({
    required String name,
    required ConfigFileObjectIdentifiers kind,
    @PixelConverter() @JsonKey(name: 'color_data', readValue: _extractFirstLed) @Default(Pixel())
    Pixel color,
  }) = _DumbLed;

  factory DumbLed.fromJson(Map<String, dynamic> json, [String? name]) =>
      _$DumbLedFromJson(name != null ? {...json, 'name': name} : json);

  factory DumbLed.partialUpdate(
      DumbLed current, Map<String, dynamic> partialJson) {
    var mergedJson = {...current.toJson(), ...partialJson};
    return DumbLed.fromJson(mergedJson);
  }
}

Object? _extractFirstLed(Map json, String key) {
  return json[key][0];
}