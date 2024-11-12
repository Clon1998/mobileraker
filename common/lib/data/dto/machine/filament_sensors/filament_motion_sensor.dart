/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/filament_sensors/filament_sensor.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../config/config_file_object_identifiers_enum.dart';

part 'filament_motion_sensor.freezed.dart';
part 'filament_motion_sensor.g.dart';

/*

"filament_motion_sensor filament_sensor": {
  "filament_detected": true,
  "enabled": true
  }
}
 */

@freezed
class FilamentMotionSensor with _$FilamentMotionSensor implements FilamentSensor {
  const FilamentMotionSensor._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory FilamentMotionSensor({
    required String name,
    @Default(true) bool filamentDetected,
    @Default(false) bool enabled,
  }) = _FilamentMotionSensor;

  factory FilamentMotionSensor.fromJson(Map<String, dynamic> json, [String? name]) =>
      _$FilamentMotionSensorFromJson(name != null ? {...json, 'name': name} : json);

  factory FilamentMotionSensor.partialUpdate(FilamentMotionSensor current, Map<String, dynamic> partialJson) {
    var mergedJson = {...current.toJson(), ...partialJson};
    return FilamentMotionSensor.fromJson(mergedJson);
  }

  @override
  ConfigFileObjectIdentifiers get kind => ConfigFileObjectIdentifiers.filament_motion_sensor;
}
