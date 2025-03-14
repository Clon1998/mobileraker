/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../config/config_file_object_identifiers_enum.dart';
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
  const FilamentSwitchSensor._();

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

  @override
  ConfigFileObjectIdentifiers get kind => ConfigFileObjectIdentifiers.filament_switch_sensor;
}
