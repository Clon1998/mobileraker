/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

mixin HeaterMixin {
  double get temperature;

  double get target;

  double get power;

  List<double>? get temperatureHistory;

  List<double>? get targetHistory;

  List<double>? get powerHistory;

  String get name;
}
