/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/filament_sensors/filament_motion_sensor.dart';
import 'package:common/data/dto/machine/filament_sensors/filament_switch_sensor.dart';

import '../../config/config_file_object_identifiers_enum.dart';

abstract interface class FilamentSensor {
  abstract final String name;
  abstract final bool filamentDetected;
  abstract final bool enabled;

  ConfigFileObjectIdentifiers get kind;

  factory FilamentSensor.fallback(ConfigFileObjectIdentifiers identifier, String name) {
    return switch (identifier) {
      ConfigFileObjectIdentifiers.filament_motion_sensor => FilamentMotionSensor(name: name),
      ConfigFileObjectIdentifiers.filament_switch_sensor => FilamentSwitchSensor(name: name),
      _ => throw UnsupportedError('Unknown FilamentSensor type: $identifier, can not create fallback.'),
    };
  }

  factory FilamentSensor.partialUpdate(FilamentSensor current, Map<String, dynamic> partialJson) {
    if (current is FilamentMotionSensor) {
      return FilamentMotionSensor.partialUpdate(current, partialJson);
    } else if (current is FilamentSwitchSensor) {
      return FilamentSwitchSensor.partialUpdate(current, partialJson);
    } else {
      throw UnsupportedError('The provided FilamentSensor type is not supported');
    }
  }
}
