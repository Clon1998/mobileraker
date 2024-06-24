/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import 'named_fan.dart';

part 'heater_fan.freezed.dart';
part 'heater_fan.g.dart';

@freezed
class HeaterFan extends NamedFan with _$HeaterFan {
  const HeaterFan._();
  const factory HeaterFan({
    required String name,
    @Default(0) double speed,
    double? rpm,
  }) = _HeaterFan;

  factory HeaterFan.fromJson(Map<String, dynamic> json, [String? name]) =>
      _$HeaterFanFromJson(name != null ? {...json, 'name': name} : json);

  factory HeaterFan.partialUpdate(
      HeaterFan current, Map<String, dynamic> partialJson) {
    var mergedJson = {...current.toJson(), ...partialJson};
    return HeaterFan.fromJson(mergedJson);
  }
}
