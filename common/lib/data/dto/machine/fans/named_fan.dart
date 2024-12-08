/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/fans/controller_fan.dart';
import 'package:common/data/dto/machine/fans/generic_fan.dart';
import 'package:common/data/dto/machine/fans/temperature_fan.dart';

import '../../config/config_file_object_identifiers_enum.dart';
import 'fan.dart';
import 'heater_fan.dart';

abstract class NamedFan implements Fan {
  const NamedFan();

  abstract final String name;

  String get configName => name.toLowerCase();

  factory NamedFan.fallback(ConfigFileObjectIdentifiers identifier, String name) {
    return switch (identifier) {
      ConfigFileObjectIdentifiers.heater_fan => HeaterFan(name: name),
      ConfigFileObjectIdentifiers.controller_fan => ControllerFan(name: name),
      ConfigFileObjectIdentifiers.temperature_fan => TemperatureFan(name: name, lastHistory: DateTime(1990)),
      ConfigFileObjectIdentifiers.fan_generic => GenericFan(name: name),
      _ => throw UnsupportedError('Unknown fan type: $identifier, can not create fallback.'),
    };
  }

  factory NamedFan.partialUpdate(NamedFan current, Map<String, dynamic> partialJson) {
    return switch (current) {
      HeaterFan() => HeaterFan.partialUpdate(current, partialJson),
      ControllerFan() => ControllerFan.partialUpdate(current, partialJson),
      TemperatureFan() => TemperatureFan.partialUpdate(current, partialJson),
      GenericFan() => GenericFan.partialUpdate(current, partialJson),
      _ => throw UnsupportedError('Unknown fan type: $current, cant partial update it.'),
    };
  }
}
