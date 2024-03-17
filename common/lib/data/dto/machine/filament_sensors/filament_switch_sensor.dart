/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import 'filament_sensor.dart';

part 'filament_switch_sensor.freezed.dart';
part 'filament_switch_sensor.g.dart';

/*

"filament_switch_sensor filament_sensor": {
  "filament_detected": true,
  "enabled": true
  }
}
 */

@freezed
class FilamentSwitchSensor with _$FilamentSwitchSensor implements FilamentSensor {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory FilamentSwitchSensor({
    required String name,
    @Default(true) bool filamentDetected,
    @Default(false) bool enabled,
  }) = _FilamentSwitchSensor;

  factory FilamentSwitchSensor.fromJson(Map<String, dynamic> json, [String? name]) =>
      _$FilamentSwitchSensorFromJson(name != null ? {...json, 'name': name} : json);

  factory FilamentSwitchSensor.partialUpdate(FilamentSwitchSensor current, Map<String, dynamic> partialJson) {
    var mergedJson = {...current.toJson(), ...partialJson};
    return FilamentSwitchSensor.fromJson(mergedJson);
  }
}
