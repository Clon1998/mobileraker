/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'config_screw.freezed.dart';
part 'config_screw.g.dart';

/// Models a "screw" that is part of a configuration.
/// This can be a bed screw or an actual screw.
@freezed
class ConfigScrew with _$ConfigScrew {
  const ConfigScrew._();

  const factory ConfigScrew({
    // NOTE THE INDEX is 1-based (1, 2, 3, ...)
    required int index,
    required String name,
    required List<double> position,
    @JsonKey(name: 'fine_adjust') List<double>? finePosition,
  }) = _ConfigScrew;

  factory ConfigScrew.fromJson(Map<String, dynamic> json) => _$ConfigScrewFromJson(json);

  double get x => position[0];

  double get y => position[1];
}

/// Helps to parse a list of screws from a JSON map.
/// The screws are stored in the map with keys like "screw1", "screw2", etc.
/// The position of the screw is stored in the value of the key.
/// The name of the screw is stored in the value of the key with the suffix "_name".
List<dynamic> readScrewList(Map input, String key) {
  Map<int, Map<String, dynamic>> out = {};
  var json = input.cast<String, dynamic>();

  json.keys.where((key) => key.startsWith(RegExp(r'screw\d+', caseSensitive: false))).forEach((key) {
    var split = key.split('_');
    String screwName = split[0];
    // remap #screw1: -> position
    String screwAtt = (split.length == 1) ? 'position' : split.sublist(1).join('_');

    int screwIndex = int.parse(screwName.substring(5));
    var screwJson = out.putIfAbsent(screwIndex, () => {'index': screwIndex});

    screwJson[screwAtt] = json[key];
  });

  return out.values.toList();
}
