/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/data/dto/config/config_output.dart';

void main() {
  test('ConfigOutput.fromJson() creates ConfigOutput instance from JSON', () {
    final jsonString = '''
        {
          "pwm": false,
          "pin": "EXP1_1",
          "maximum_mcu_duration": 0,
          "value": 0,
          "shutdown_value": 0
        }
      ''';

    final jsonMap = json.decode(jsonString);
    final configOutput = ConfigOutput.fromJson('test', jsonMap);

    expect(configOutput.name, 'test');
    expect(configOutput.pwm, false);
    expect(configOutput.scale, 1.0);
  });
}
