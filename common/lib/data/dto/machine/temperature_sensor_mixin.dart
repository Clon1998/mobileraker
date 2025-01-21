/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import '../config/config_file_object_identifiers_enum.dart';

mixin TemperatureSensorMixin {
  double get temperature;

  String get name;

  String get configName => name.toLowerCase();

  ConfigFileObjectIdentifiers get kind;

  /// Returns the config entry for the sensor in the config file
  /// Example: 'temperature sensor1'
  String get configEntry => '${kind.name} $configName';
}
