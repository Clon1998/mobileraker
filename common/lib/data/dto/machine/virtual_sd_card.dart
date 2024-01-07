/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/integer_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'virtual_sd_card.freezed.dart';
part 'virtual_sd_card.g.dart';

@freezed
class VirtualSdCard with _$VirtualSdCard {
  const factory VirtualSdCard({
    @Default(0) double progress,
    @JsonKey(name: 'is_active') @Default(false) bool isActive,
    @IntegerConverter() @JsonKey(name: 'file_position') @Default(0) int filePosition,
  }) = _VirtualSdCard;

  factory VirtualSdCard.fromJson(Map<String, dynamic> json) => _$VirtualSdCardFromJson(json);

  factory VirtualSdCard.partialUpdate(VirtualSdCard? current, Map<String, dynamic> partialJson) {
    VirtualSdCard old = current ?? const VirtualSdCard();
    var mergedJson = {...old.toJson(), ...partialJson};
    return VirtualSdCard.fromJson(mergedJson);
  }
}
