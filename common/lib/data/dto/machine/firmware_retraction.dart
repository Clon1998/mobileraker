/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'firmware_retraction.freezed.dart';
part 'firmware_retraction.g.dart';

// "firmware_retraction": {
// "retract_length": 0.5,
// "retract_speed": 35,
// "unretract_extra_length": 0,
// "unretract_speed": 30
// }

@freezed
class FirmwareRetraction with _$FirmwareRetraction {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory FirmwareRetraction({
    required double retractLength,
    required double retractSpeed,
    required double unretractExtraLength,
    required double unretractSpeed,
  }) = _FirmwareRetraction;

  factory FirmwareRetraction.fromJson(Map<String, dynamic> json) => _$FirmwareRetractionFromJson(json);

  factory FirmwareRetraction.partialUpdate(FirmwareRetraction? current, Map<String, dynamic> partialJson) {
    if (current == null) return FirmwareRetraction.fromJson(partialJson);

    var mergedJson = {...current.toJson(), ...partialJson};
    return FirmwareRetraction.fromJson(mergedJson);
  }
}
