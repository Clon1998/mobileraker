/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/integer_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bed_screw.freezed.dart';
part 'bed_screw.g.dart';

// "bed_screws": {
//   "state": "adjust", // nullable, either adjust or fine (For fineAdjust mode???)
//   "is_active": true,
//   "accepted_screws": 0,
//   "current_screw": 0
// }

enum BedScrewMode { adjust, fine }

@freezed
class BedScrew with _$BedScrew {
  const factory BedScrew({
    @JsonKey(name: 'is_active') @Default(false) bool isActive,
    BedScrewMode? state,
    @IntegerConverter() @JsonKey(name: 'accepted_screws') @Default(0) int acceptedScrews,
    @IntegerConverter() @JsonKey(name: 'current_screw') @Default(0) int currentScrew,
  }) = _BedScrew;

  factory BedScrew.fromJson(Map<String, dynamic> json) => _$BedScrewFromJson(json);

  factory BedScrew.partialUpdate(BedScrew? current, Map<String, dynamic> partialJson) {
    BedScrew old = current ?? const BedScrew();
    var mergedJson = {...old.toJson(), ...partialJson};
    return BedScrew.fromJson(mergedJson);
  }
}
