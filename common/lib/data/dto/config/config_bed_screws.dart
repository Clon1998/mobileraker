/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'config_bed_screws.freezed.dart';
part 'config_bed_screws.g.dart';

// {
//   "screw1_name": "screw at 100.000,50.000",
//   "probe_speed": 5,
//   "speed": 50,
//   "probe_height": 0,
//   "horizontal_move_z": 5,
//   "screw2_name": "screw at 100.000,150.000",
//   "screw2": [100,150],
//   "screw3": [150,100],
//   "screw1": [100,50],
//   "screw3_name": "screw at 150.000,100.000"
// "screw1_fine_adjust": [150,100], (Empty in most cases/not contained since not required)
// ... screws are unlimted!
// }

@freezed
class ConfigBedScrews with _$ConfigBedScrews {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ConfigBedScrews({
    @Default(5) double horizontalMoveZ,
    @Default(0) double probeHeight,
    @Default(50) double probeSpeed,
    @Default(5) double speed,
    @JsonKey(readValue: _constructScrews) required List<ConfigScrew> screws,
  }) = _ConfigBedScrews;

  factory ConfigBedScrews.fromJson(Map<String, dynamic> json) =>
      _$ConfigBedScrewsFromJson(json);
}

List<dynamic> _constructScrews(Map input, String key) {
  Map<int, Map<String, dynamic>> out = {};
  var json = input.cast<String, dynamic>();

  json.keys.where((key) => key.startsWith('screw')).forEach((key) {
    var split = key.split('_');
    String screwName = split[0];
    // remap #screw1: -> position
    String screwAtt =
    (split.length == 1) ? 'position' : split.sublist(1).join('_');

    int screwIndex = int.parse(screwName.substring(5));
    var screwJson = out.putIfAbsent(screwIndex, () => {});

    screwJson[screwAtt] = json[key];
  });

  return out.values.toList();
}

@freezed
class ConfigScrew with _$ConfigScrew {
  const ConfigScrew._();

  const factory ConfigScrew({
    required String name,
    required List<double> position,
    @JsonKey(name: 'fine_adjust') List<double>? finePosition,
  }) = _ConfigScrew;

  factory ConfigScrew.fromJson(Map<String, dynamic> json) =>
      _$ConfigScrewFromJson(json);

  double get x => position[0];

  double get y => position[1];
}
