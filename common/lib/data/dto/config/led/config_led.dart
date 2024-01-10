/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */



// part 'led.freezed.dart';
//
// @freezed
// class Pixel with _$Pixel {
//   const Pixel._();
//
//   const factory Pixel({
//     @Default(0) double red,
//     @Default(0) double green,
//     @Default(0) double blue,
//     @Default(0) double white,
//   }) = _Pixel;
//
//   factory Pixel.fromList(List<double> list) {
//     return Pixel(red: list[0], green: list[1], blue: list[2], white: list[3]);
//   }
// }

abstract class ConfigLed {
  const ConfigLed();
  abstract final String name;

  bool get isSingleColor => false;

  bool get isAddressable => false;

  bool get hasWhite;
}
