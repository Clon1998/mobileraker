/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import '../temperature_sensor_mixin.dart';

mixin HeaterMixin on TemperatureSensorMixin {
  double get target;

  double get power;
}
