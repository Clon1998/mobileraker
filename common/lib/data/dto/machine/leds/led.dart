/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import 'addressable_led.dart';
import 'dumb_led.dart';

part 'led.freezed.dart';

@freezed
class Pixel with _$Pixel {
  const Pixel._();

  const factory Pixel({
    @Default(0) double red,
    @Default(0) double green,
    @Default(0) double blue,
    @Default(0) double white,
    @Default(false) bool legacy,
  }) = _Pixel;

  factory Pixel.fromList(List<double> list) {
    return Pixel(
        red: list.elementAtOrNull(0) ?? 0,
        green: list.elementAtOrNull(1) ?? 0,
        blue: list.elementAtOrNull(2) ?? 0,
        white: list.elementAtOrNull(3) ?? 0);
  }

  factory Pixel.fromMap(Map<String, double> map) {
    return Pixel(
      red: map['R'] ?? 0,
      green: map['G'] ?? 0,
      blue: map['B'] ?? 0,
      white: map['W'] ?? 0,
      legacy: true,
    );
  }

  List<double> asList() => [red, green, blue, white];

  Map<String, double> asMap() => {'R': red, 'G': green, 'B': blue, 'W': white};

  bool get hasColor => red + green + blue + white > 0;
}

abstract class Led {
  const Led();

  abstract final String name;

  String get configName => name.toLowerCase();

  factory Led.partialUpdate(Led current, Map<String, dynamic> partialJson) {
    if (current is DumbLed) {
      return DumbLed.partialUpdate(current, partialJson);
    } else if (current is AddressableLed) {
      return AddressableLed.partialUpdate(current, partialJson);
    } else {
      throw UnsupportedError('The provided LED Type is not implemented yet!');
    }
  }
}
