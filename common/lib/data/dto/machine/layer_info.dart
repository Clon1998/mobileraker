/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../converters/integer_converter.dart';

part 'layer_info.freezed.dart';
part 'layer_info.g.dart';

@freezed
class LayerInfo with _$LayerInfo {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LayerInfo({
    @IntegerConverter() int? currentLayer,
    @IntegerConverter() int? totalLayer,
  }) = _LayerInfo;

  factory LayerInfo.fromJson(Map<String, dynamic> json) => _$LayerInfoFromJson(json);
}
