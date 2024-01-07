/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../converters/double_precision_converter.dart';

part 'manual_probe.freezed.dart';
part 'manual_probe.g.dart';

// {
// "z_position": 5.27124999998297,
// "is_active": true,
// "z_position_upper": 5.321249999982925,
// "z_position_lower": 5.221249999983016
// }

@freezed
class ManualProbe with _$ManualProbe {
  const factory ManualProbe({
    @JsonKey(name: 'is_active') @Default(false) bool isActive,
    @Double3PrecisionConverter() @JsonKey(name: 'z_position') double? zPosition,
    @Double3PrecisionConverter() @JsonKey(name: 'z_position_upper') double? zPositionUpper,
    @Double3PrecisionConverter() @JsonKey(name: 'z_position_lower') double? zPositionLower,
  }) = _ManualProbe;

  factory ManualProbe.fromJson(Map<String, dynamic> json) =>
      _$ManualProbeFromJson(json);

  factory ManualProbe.partialUpdate(ManualProbe? current, Map<String, dynamic> partialJson) {
    ManualProbe old = current ?? const ManualProbe();
    var mergedJson = {...old.toJson(), ...partialJson};
    return ManualProbe.fromJson(mergedJson);
  }
}
