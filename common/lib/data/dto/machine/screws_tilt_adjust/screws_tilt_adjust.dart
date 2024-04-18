/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/converters/double_precision_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'screw_tilt_result.dart';

part 'screws_tilt_adjust.freezed.dart';
part 'screws_tilt_adjust.g.dart';

/*

{
  "screws_tilt_adjust": {
    "error": false,
    "max_deviation": null,
    "results": {
      "screw1": {
        "z": 1.898139118417935,
        "sign": "CW",
        "adjust": "00:00",
        "is_base": true
      },
      "screw2": {
        "z": 1.9982132348547421,
        "sign": "CCW",
        "adjust": "00:12",
        "is_base": false
      },
      "screw3": {
        "z": 2.000246330519063,
        "sign": "CCW",
        "adjust": "00:12",
        "is_base": false
      },
      "screw4": {
        "z": 1.9753139553884536,
        "sign": "CCW",
        "adjust": "00:09",
        "is_base": false
      }
    }
  }
}
 */

@freezed
class ScrewsTiltAdjust with _$ScrewsTiltAdjust {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ScrewsTiltAdjust({
    @Default(false) bool error,
    @Double3PrecisionConverter() double? maxDeviation,
    @JsonKey(fromJson: _parseResults, toJson: _deparseResults) @Default([]) List<ScrewTiltResult> results,
  }) = _ScrewsTiltAdjust;

  factory ScrewsTiltAdjust.fromJson(Map<String, dynamic> json) => _$ScrewsTiltAdjustFromJson(json);

  factory ScrewsTiltAdjust.partialUpdate(ScrewsTiltAdjust? current, Map<String, dynamic> partialJson) {
    ScrewsTiltAdjust old = current ?? const ScrewsTiltAdjust();
    var mergedJson = {...old.toJson(), ...partialJson};
    return ScrewsTiltAdjust.fromJson(mergedJson);
  }
}

List<ScrewTiltResult> _parseResults(dynamic raw) {
  return switch (raw) {
    Map e => e.entries
        .map((e) {
          String screwName = e.key;
          Map<String, dynamic> value = (e.value as Map).map((key, value) => MapEntry(key as String, value));

          return ScrewTiltResult.fromJson(screwName, value);
        })
        // sort the entires by name ignoring case
        .sorted((a, b) => compareAsciiLowerCaseNatural(a.screw, b.screw))
        .toList(),
    _ => []
  };
}

Map _deparseResults(List<ScrewTiltResult> results) {
  return {
    for (var result in results) result.screw: result.toJson(),
  };
}
