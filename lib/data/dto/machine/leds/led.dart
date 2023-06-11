/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'led.freezed.dart';

@freezed
class Pixel with _$Pixel {
  const Pixel._();

  const factory Pixel({
    @Default(0) double red,
    @Default(0) double green,
    @Default(0) double blue,
    @Default(0) double white,
  }) = _Pixel;

  factory Pixel.fromList(List<double> list) {
    return Pixel(red: list[0], green: list[1], blue: list[2], white: list[3]);
  }

  List<double> asList() => [red, green, blue, white];

  bool get hasColor => red + green + blue + white > 0;
}

abstract class Led {
  abstract final String name;
}
