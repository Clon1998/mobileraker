/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../converters/string_integer_converter.dart';

part 'layer_info.freezed.dart';
part 'layer_info.g.dart';

@freezed
class LayerInfo with _$LayerInfo {
  @StringIntegerConverter()
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LayerInfo({
    int? currentLayer,
    int? totalLayer,
  }) = _LayerInfo;

  factory LayerInfo.fromJson(Map<String, dynamic> json) => _$LayerInfoFromJson(json);
}
