/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/double_precision_converter.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'screw_tilt_result.freezed.dart';
part 'screw_tilt_result.g.dart';

/*
      "screw4": {
        "z": 1.9753139553884536,
        "sign": "CCW",
        "adjust": "00:09",
        "is_base": false
      }

 */

@freezed
class ScrewTiltResult with _$ScrewTiltResult {
  const ScrewTiltResult._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ScrewTiltResult({
    required String screw,
    @Double4PrecisionConverter() required double z,
    required String sign,
    // Returns the screw adjustment in HH:MM format
    required String adjust,
    // Is it the screw of which the adjustments are based on
    @Default(false) bool isBase,
  }) = _ScrewTiltResult;

  int get adjustMinutes => adjust.split(':').map(int.parse).reduce((a, b) => a * 60 + b);

  factory ScrewTiltResult.fromJson(String screw, Map<String, dynamic> json) =>
      _$ScrewTiltResultFromJson({'screw': screw, ...json});
}
