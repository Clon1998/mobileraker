/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/config/config_output.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConfigOutput.fromJson() creates ConfigOutput instance from JSON', () {
    const jsonString = '''
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
