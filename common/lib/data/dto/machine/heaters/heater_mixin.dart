/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import '../sensor_mixin.dart';

mixin HeaterMixin on SensorMixin {
  double get target;

  double get power;

  List<double>? get targetHistory;

  List<double>? get powerHistory;
}
