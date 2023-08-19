/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/integer_converter.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'gcode_thumbnail.freezed.dart';
part 'gcode_thumbnail.g.dart';

// {
// "width": 32,
// "height": 24,
// "size": 2201,
// "relative_path": ".thumbs/TAP_UPPER_PCB_RC8_18.4613g_0.2mm_ABS-1h34m-32x32.png"
// },
@freezed
class GCodeThumbnail with _$GCodeThumbnail {
  const factory GCodeThumbnail({
    @IntegerConverter() required int width,
    @IntegerConverter() required int height,
    @IntegerConverter() required int size,
    @JsonKey(name: 'relative_path') required String relativePath,
  }) = _GCodeThumbnail;

  factory GCodeThumbnail.fromJson(Map<String, dynamic> json) => _$GCodeThumbnailFromJson(json);
}
