/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import 'config_screw.dart';

part 'config_screws_tilt_adjust.freezed.dart';
part 'config_screws_tilt_adjust.g.dart';

// {
//   "screw_thread": "CW-M3",
//   "horizontal_move_z": 5,
//   "speed": 50,
//   "screw1_name": "screw at 100.000,50.000",
//   "screw2_name": "screw at 100.000,150.000",
//   "screw2": [100,150],
//   "screw3": [150,100],
//   "screw1": [100,50],
//   "screw3_name": "screw at 150.000,100.000"
// ... screws are unlimted!
// }

@freezed
class ConfigScrewsTiltAdjust with _$ConfigScrewsTiltAdjust {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ConfigScrewsTiltAdjust({
    @Default('CW-M3') String screwThread,
    @Default(5) double horizontalMoveZ,
    @Default(50) double speed,
    @JsonKey(readValue: readScrewList) required List<ConfigScrew> screws,
  }) = _ConfigScrewsTiltAdjust;

  factory ConfigScrewsTiltAdjust.fromJson(Map<String, dynamic> json) => _$ConfigScrewsTiltAdjustFromJson(json);
}
