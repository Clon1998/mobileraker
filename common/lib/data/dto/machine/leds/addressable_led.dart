/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../converters/pixel_converter.dart';
import 'led.dart';

part 'addressable_led.freezed.dart';
part 'addressable_led.g.dart';

@freezed
class AddressableLed extends Led with _$AddressableLed {
  const AddressableLed._();
  const factory AddressableLed({
    required String name,
    @PixelConverter() @JsonKey(name: 'color_data') @Default([]) List<Pixel> pixels,
  }) = _AddressableLed;

  factory AddressableLed.fromJson(Map<String, dynamic> json, [String? name]) =>
      _$AddressableLedFromJson(name != null ? {...json, 'name': name} : json);

  factory AddressableLed.partialUpdate(AddressableLed current, Map<String, dynamic> partialJson) {
    var mergedJson = {...current.toJson(), ...partialJson};
    return AddressableLed.fromJson(mergedJson);
  }
}
