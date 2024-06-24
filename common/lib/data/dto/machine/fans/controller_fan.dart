/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import 'named_fan.dart';

part 'controller_fan.freezed.dart';
part 'controller_fan.g.dart';

@freezed
class ControllerFan extends NamedFan with _$ControllerFan {
  const ControllerFan._();
  const factory ControllerFan({
    required String name,
    @Default(0) double speed,
    double? rpm,
  }) = _ControllerFan;

  factory ControllerFan.fromJson(Map<String, dynamic> json, [String? name]) =>
      _$ControllerFanFromJson(name != null ? {...json, 'name': name} : json);

  factory ControllerFan.partialUpdate(
      ControllerFan current, Map<String, dynamic> partialJson) {
    var mergedJson = {...current.toJson(), ...partialJson};
    return ControllerFan.fromJson(mergedJson);
  }
}
