/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/config/fan/config_generic_fan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConfigGenericFan.fromJson() non PWM', () {
    const str = '''
  {
    "max_power": 1,
    "kick_start_time": 0.5,
    "off_below": 0,
    "cycle_time": 0.01,
    "hardware_pwm": false,
    "shutdown_speed": 0,
    "pin": "PD14"
  }
    ''';
    var strToJson = jsonDecode(str);

    var configGenericFan = ConfigGenericFan.fromJson('exhaust_fan', strToJson);

    expect(configGenericFan, isNotNull);
    expect(configGenericFan.name, 'exhaust_fan');
    expect(configGenericFan.maxPower, 1);
    expect(configGenericFan.kickStartTime, 0.5);
    expect(configGenericFan.offBelow, 0);
    expect(configGenericFan.cycleTime, 0.01);
    expect(configGenericFan.hardwarePwm, false);
    expect(configGenericFan.shutdownSpeed, 0);
    expect(configGenericFan.pin, 'PD14');
    expect(configGenericFan.tachometerPin, isNull);
    expect(configGenericFan.tachometerPpr, 2);
    expect(configGenericFan.tachometerPollInterval, 0.0015);
    expect(configGenericFan.enablePin, isNull);
  });

  test('ConfigGenericFan.fromJson() PWM', () {
    const str = '''
  {
    "max_power": 1,
    "kick_start_time": 0.5,
    "off_below": 0,
    "cycle_time": 0.01,
    "hardware_pwm": false,
    "shutdown_speed": 0,
    "pin": "PD14",
    "tachometer_pin": "PA2",
    "tachometer_ppr": 4,
    "tachometer_poll_interval": 0.3,
    "enable_pin": "PA1"
  }
    ''';
    var strToJson = jsonDecode(str);

    var configGenericFan = ConfigGenericFan.fromJson('exhaust_fan', strToJson);

    expect(configGenericFan, isNotNull);
    expect(configGenericFan.name, 'exhaust_fan');
    expect(configGenericFan.maxPower, 1);
    expect(configGenericFan.kickStartTime, 0.5);
    expect(configGenericFan.offBelow, 0);
    expect(configGenericFan.cycleTime, 0.01);
    expect(configGenericFan.hardwarePwm, false);
    expect(configGenericFan.shutdownSpeed, 0);
    expect(configGenericFan.pin, 'PD14');
    expect(configGenericFan.tachometerPin, 'PA2');
    expect(configGenericFan.tachometerPpr, 4);
    expect(configGenericFan.tachometerPollInterval, 0.3);
    expect(configGenericFan.enablePin, 'PA1');
  });
}
