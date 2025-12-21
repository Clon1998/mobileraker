/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_double_converter.dart';
import 'package:common/data/converters/string_integer_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'virtual_sd_card.freezed.dart';
part 'virtual_sd_card.g.dart';

@freezed
class VirtualSdCard with _$VirtualSdCard {
  @StringIntegerConverter()
  @StringDoubleConverter()
  const factory VirtualSdCard({
    @Default(0) double progress,
    @JsonKey(name: 'is_active') @Default(false) bool isActive,
    @JsonKey(name: 'file_position') @Default(0) int filePosition,
  }) = _VirtualSdCard;

  factory VirtualSdCard.fromJson(Map<String, dynamic> json) => _$VirtualSdCardFromJson(json);

  factory VirtualSdCard.partialUpdate(VirtualSdCard? current, Map<String, dynamic> partialJson) {
    VirtualSdCard old = current ?? const VirtualSdCard();
    var mergedJson = {...old.toJson(), ...partialJson};
    return VirtualSdCard.fromJson(mergedJson);
  }
}
