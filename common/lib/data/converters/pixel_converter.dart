/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:json_annotation/json_annotation.dart';

import '../dto/machine/leds/led.dart';

class PixelConverter extends JsonConverter<Pixel, List<dynamic>> {
  const PixelConverter();

  @override
  Pixel fromJson(List<dynamic> json) {
    if (json.isEmpty) return const Pixel();

    var list = json.map((e) => (e as num).toDouble()).toList();
    return Pixel.fromList(list);
  }

  @override
  List<dynamic> toJson(Pixel object) => object.asList().toList(growable: false);
}
