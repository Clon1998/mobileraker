/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/pins/output_pin.dart';
import 'package:common/data/dto/machine/pins/pwm_tool.dart';

import '../../config/config_file_object_identifiers_enum.dart';

abstract class Pin {
  const Pin();

  abstract final String name;

  abstract final double value;

  ConfigFileObjectIdentifiers get kind;

  String get configName => name.toLowerCase();

  factory Pin.fallback(ConfigFileObjectIdentifiers identifier, String name) {
    return switch (identifier) {
      ConfigFileObjectIdentifiers.output_pin =>
          OutputPin(name: name),
      ConfigFileObjectIdentifiers.pwm_tool =>
          PwmTool(name: name),
      _ => throw UnsupportedError('Unknown pin type: $identifier, can not create fallback.'),
    };
  }

  factory Pin.partialUpdate(Pin current, Map<String, dynamic> partialJson) {
    if (current is OutputPin) {
      return OutputPin.partialUpdate(current, partialJson);
    } else if (current is PwmTool) {
      return PwmTool.partialUpdate(current, partialJson);
    } else {
      throw UnsupportedError('The provided pin Type is not implemented yet!');
    }
  }
}