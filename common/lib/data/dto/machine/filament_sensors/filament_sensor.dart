/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/filament_sensors/filament_motion_sensor.dart';
import 'package:common/data/dto/machine/filament_sensors/filament_switch_sensor.dart';

abstract interface class FilamentSensor {
  abstract final String name;
  abstract final bool filamentDetected;
  abstract final bool enabled;

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
