/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/config/fan/config_print_cooling_fan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConfigPrintCoolingFan.fromJson() non PWM', () {
    const str = '''
 {
    "max_power": 1,
    "kick_start_time": 0.5,
    "off_below": 0.1,
    "cycle_time": 0.01,
    "hardware_pwm": false,
    "shutdown_speed": 0,
    "pin": "PA8"
  }
    ''';
    var strToJson = jsonDecode(str);

    var configPrintCoolingFan = ConfigPrintCoolingFan.fromJson(strToJson);

    expect(configPrintCoolingFan, isNotNull);
    expect(configPrintCoolingFan.maxPower, 1);
    expect(configPrintCoolingFan.kickStartTime, 0.5);
    expect(configPrintCoolingFan.offBelow, 0.1);
    expect(configPrintCoolingFan.cycleTime, 0.01);
    expect(configPrintCoolingFan.hardwarePwm, false);
    expect(configPrintCoolingFan.shutdownSpeed, 0);
    expect(configPrintCoolingFan.pin, 'PA8');
    expect(configPrintCoolingFan.tachometerPin, isNull);
    expect(configPrintCoolingFan.tachometerPpr, 2);
    expect(configPrintCoolingFan.tachometerPollInterval, 0.0015);
    expect(configPrintCoolingFan.enablePin, isNull);
  });

  test('ConfigPrintCoolingFan.fromJson() PWM', () {
    const str = '''
 {
    "max_power": 1,
    "kick_start_time": 0.5,
    "off_below": 0.1,
    "cycle_time": 0.01,
    "hardware_pwm": false,
    "shutdown_speed": 0,
    "pin": "PA8",
    "tachometer_pin": "PA2",
    "tachometer_ppr": 4,
    "tachometer_poll_interval": 0.3,
    "enable_pin": "PA1"
  }
    ''';
    var strToJson = jsonDecode(str);

    var configPrintCoolingFan = ConfigPrintCoolingFan.fromJson(strToJson);

    expect(configPrintCoolingFan, isNotNull);
    expect(configPrintCoolingFan.kickStartTime, 0.5);
    expect(configPrintCoolingFan.offBelow, 0.1);
    expect(configPrintCoolingFan.cycleTime, 0.01);
    expect(configPrintCoolingFan.hardwarePwm, false);
    expect(configPrintCoolingFan.shutdownSpeed, 0);
    expect(configPrintCoolingFan.pin, 'PA8');
    expect(configPrintCoolingFan.tachometerPin, 'PA2');
    expect(configPrintCoolingFan.tachometerPpr, 4);
    expect(configPrintCoolingFan.tachometerPollInterval, 0.3);
    expect(configPrintCoolingFan.enablePin, 'PA1');
  });
}
