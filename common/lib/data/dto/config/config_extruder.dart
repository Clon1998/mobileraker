/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'config_extruder.freezed.dart';
part 'config_extruder.g.dart';

@freezed
class ConfigExtruder with _$ConfigExtruder {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ConfigExtruder({
    required String name,
    required double nozzleDiameter,
    required double maxExtrudeOnlyDistance,
    required double minTemp,
    required double minExtrudeTemp,
    required double maxTemp,
    required double maxPower,
    required double filamentDiameter,
    required double maxExtrudeOnlyVelocity, // mm/s
    required double maxExtrudeOnlyAccel, // mm/s^2
  }) = _ConfigExtruder;

  factory ConfigExtruder.fromJson(String name, Map<String, dynamic> json) =>
      _$ConfigExtruderFromJson({'name': name, ...json});
}
