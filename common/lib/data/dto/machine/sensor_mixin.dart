/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

mixin SensorMixin {
  double get temperature;

  List<double>? get temperatureHistory;

  String get name;

  String get configName => name.toLowerCase();
}
