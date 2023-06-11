/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'virtual_sd_card.freezed.dart';

@freezed
class VirtualSdCard with _$VirtualSdCard {
  const factory VirtualSdCard({
    @Default(0) double progress,
    @Default(false) bool isActive,
    @Default(0) int filePosition,
  }) = _VirtualSdCard;
}
