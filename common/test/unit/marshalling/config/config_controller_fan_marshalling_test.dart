/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/config/fan/config_controller_fan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConfigControllerFan.fromJson() non PWM', () {
    const str = '''
{
    "max_power": 1,
    "kick_start_time": 0.5,
    "off_below": 0,
    "cycle_time": 0.01,
    "hardware_pwm": false,
    "shutdown_speed": 0,
    "pin": "PB10",
    "fan_speed": 1,
    "idle_speed": 1,
    "idle_timeout": 30,
    "heater": [
      "heater_bed"
    ]
  }
    ''';
    var strToJson = jsonDecode(str);

    var configControllerFan = ConfigControllerFan.fromJson('exhaust_fan', strToJson);

    expect(configControllerFan, isNotNull);
    expect(configControllerFan.name, 'exhaust_fan');
    expect(configControllerFan.maxPower, 1);
    expect(configControllerFan.kickStartTime, 0.5);
    expect(configControllerFan.offBelow, 0);
    expect(configControllerFan.cycleTime, 0.01);
    expect(configControllerFan.hardwarePwm, false);
    expect(configControllerFan.shutdownSpeed, 0);
    expect(configControllerFan.pin, 'PB10');
    expect(configControllerFan.fanSpeed, 1);
    expect(configControllerFan.idleSpeed, 1);
    expect(configControllerFan.idleTimeout, 30);
    expect(configControllerFan.heater, ['heater_bed']);
    expect(configControllerFan.stepper, []);
    expect(configControllerFan.tachometerPin, isNull);
    expect(configControllerFan.tachometerPpr, 2);
    expect(configControllerFan.tachometerPollInterval, 0.0015);
    expect(configControllerFan.enablePin, isNull);
  });

  test('ConfigControllerFan.fromJson() PWM', () {
    const str = '''
{
    "max_power": 1,
    "kick_start_time": 0.5,
    "off_below": 0,
    "cycle_time": 0.01,
    "hardware_pwm": false,
    "shutdown_speed": 0,
    "pin": "PB10",
    "fan_speed": 1,
    "idle_speed": 1,
    "idle_timeout": 30,
    "heater": [
      "heater_bed"
    ],
        "tachometer_pin": "PA2",
    "tachometer_ppr": 4,
    "tachometer_poll_interval": 0.3,
    "enable_pin": "PA1"
  }
    ''';
    var strToJson = jsonDecode(str);

    var configControllerFan = ConfigControllerFan.fromJson('exhaust_fan', strToJson);

    expect(configControllerFan, isNotNull);
    expect(configControllerFan.name, 'exhaust_fan');
    expect(configControllerFan.maxPower, 1);
    expect(configControllerFan.kickStartTime, 0.5);
    expect(configControllerFan.offBelow, 0);
    expect(configControllerFan.cycleTime, 0.01);
    expect(configControllerFan.hardwarePwm, false);
    expect(configControllerFan.shutdownSpeed, 0);
    expect(configControllerFan.pin, 'PB10');
    expect(configControllerFan.fanSpeed, 1);
    expect(configControllerFan.idleSpeed, 1);
    expect(configControllerFan.idleTimeout, 30);
    expect(configControllerFan.heater, ['heater_bed']);
    expect(configControllerFan.stepper, []);
    expect(configControllerFan.tachometerPin, 'PA2');
    expect(configControllerFan.tachometerPpr, 4);
    expect(configControllerFan.tachometerPollInterval, 0.3);
    expect(configControllerFan.enablePin, 'PA1');
  });
}
