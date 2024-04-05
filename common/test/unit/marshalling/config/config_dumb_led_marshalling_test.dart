/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/config/led/config_dumb_led.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConfigDumbLed.fromJson() all pins', () {
    const str = '''
  {
    "cycle_time": 0.01,
    "hardware_pwm": false,
    "red_pin": "PA1",
    "green_pin": "PA2",
    "blue_pin": "PA5",
    "white_pin": "PA3",
    "initial_red": 0,
    "initial_green": 0.2,
    "initial_blue": 0,
    "initial_white": 0
  }
    ''';
    var strToJson = jsonDecode(str);

    var configDumpLed = ConfigDumbLed.fromJson('caselight', strToJson);

    expect(configDumpLed, isNotNull);
    expect(configDumpLed.name, 'caselight');
    expect(configDumpLed.redPin, 'PA1');
    expect(configDumpLed.greenPin, 'PA2');
    expect(configDumpLed.bluePin, 'PA5');
    expect(configDumpLed.whitePin, 'PA3');
    expect(configDumpLed.initialRed, 0);
    expect(configDumpLed.initialGreen, 0.2);
    expect(configDumpLed.initialBlue, 0);
    expect(configDumpLed.initialWhite, 0);
  });

  test('ConfigDumbLed.fromJson() only white pin', () {
    const str = '''
  {
    "cycle_time": 0.01,
    "hardware_pwm": false,
    "white_pin": "PA3",
    "initial_red": 0,
    "initial_green": 0.2,
    "initial_blue": 0,
    "initial_white": 0
  }
    ''';
    var strToJson = jsonDecode(str);

    var configDumpLed = ConfigDumbLed.fromJson('caselight', strToJson);

    expect(configDumpLed, isNotNull);
    expect(configDumpLed.name, 'caselight');
    expect(configDumpLed.redPin, isNull);
    expect(configDumpLed.greenPin, isNull);
    expect(configDumpLed.bluePin, isNull);
    expect(configDumpLed.whitePin, 'PA3');
    expect(configDumpLed.initialRed, 0);
    expect(configDumpLed.initialGreen, 0.2);
    expect(configDumpLed.initialBlue, 0);
    expect(configDumpLed.initialWhite, 0);
  });

  test('ConfigDumbLed.fromJson() missing initial colors', () {
    const str = '''
  {
    "cycle_time": 0.01,
    "hardware_pwm": false,
    "white_pin": "PA3"
  }
    ''';
    var strToJson = jsonDecode(str);

    var configDumpLed = ConfigDumbLed.fromJson('caselight', strToJson);

    expect(configDumpLed, isNotNull);
    expect(configDumpLed.name, 'caselight');
    expect(configDumpLed.redPin, isNull);
    expect(configDumpLed.greenPin, isNull);
    expect(configDumpLed.bluePin, isNull);
    expect(configDumpLed.whitePin, 'PA3');
    expect(configDumpLed.initialRed, 0);
    expect(configDumpLed.initialGreen, 0);
    expect(configDumpLed.initialBlue, 0);
    expect(configDumpLed.initialWhite, 0);
  });
}
