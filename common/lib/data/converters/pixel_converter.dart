/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:json_annotation/json_annotation.dart';

import '../dto/machine/leds/led.dart';

class PixelConverter extends JsonConverter<Pixel, dynamic> {
  const PixelConverter();

  @override
  Pixel fromJson(dynamic json) {
    if (json is Map) {
      return fromMap((json).cast<String, dynamic>());
    } else if (json is List) {
      return fromList(json);
    } else {
      throw ArgumentError('PixelConverter: Unknown type: ${json.runtimeType}');
    }
  }

  Pixel fromList(List<dynamic> json) {
    if (json.isEmpty) return const Pixel();

    var list = json.map((e) => (e as num).toDouble()).toList();
    return Pixel.fromList(list);
  }

  Pixel fromMap(Map<String, dynamic> json) {
    if (json.isEmpty) return const Pixel();

    var map = json.map((key, value) => MapEntry(key.toUpperCase(), (value as num).toDouble()));
    return Pixel.fromMap(map);
  }

  @override
  dynamic toJson(Pixel object) => object.legacy ? object.asMap() : object.asList().toList(growable: false);
}
