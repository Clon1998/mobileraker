/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/config/fan/config_heater_fan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConfigHeaterFan.fromJson() non PWM', () {
    const str = '''
  {
    "heater": [
      "heater_bed"
    ],
    "heater_temp": 60,
    "max_power": 1,
    "kick_start_time": 0.5,
    "off_below": 0,
    "cycle_time": 0.01,
    "hardware_pwm": false,
    "shutdown_speed": 0,
    "pin": "PD12",
    "fan_speed": 1
  }
    ''';
    var strToJson = jsonDecode(str);

    var configHeaterFan = ConfigHeaterFan.fromJson('exhaust_fan', strToJson);

    expect(configHeaterFan, isNotNull);
    expect(configHeaterFan.name, 'exhaust_fan');
    expect(configHeaterFan.heater, ['heater_bed']);
    expect(configHeaterFan.heaterTemp, 60);
    expect(configHeaterFan.maxPower, 1);
    expect(configHeaterFan.kickStartTime, 0.5);
    expect(configHeaterFan.offBelow, 0);
    expect(configHeaterFan.cycleTime, 0.01);
    expect(configHeaterFan.hardwarePwm, false);
    expect(configHeaterFan.shutdownSpeed, 0);
    expect(configHeaterFan.pin, 'PD12');
    expect(configHeaterFan.fanSpeed, 1);
    expect(configHeaterFan.tachometerPin, isNull);
    expect(configHeaterFan.tachometerPpr, 2);
    expect(configHeaterFan.tachometerPollInterval, 0.0015);
    expect(configHeaterFan.enablePin, isNull);
  });

  test('ConfigHeaterFan.fromJson() non PWM', () {
    const str = '''
  {
    "heater": [
      "heater_bed"
    ],
    "heater_temp": 60,
    "max_power": 1,
    "kick_start_time": 0.5,
    "off_below": 0,
    "cycle_time": 0.01,
    "hardware_pwm": false,
    "shutdown_speed": 0,
    "pin": "PD12",
    "fan_speed": 1,
    "tachometer_pin": "PA2",
    "tachometer_ppr": 4,
    "tachometer_poll_interval": 0.3,
    "enable_pin": "PA1"
  }
    ''';
    var strToJson = jsonDecode(str);

    var configHeaterFan = ConfigHeaterFan.fromJson('exhaust_fan', strToJson);

    expect(configHeaterFan, isNotNull);
    expect(configHeaterFan.name, 'exhaust_fan');
    expect(configHeaterFan.heater, ['heater_bed']);
    expect(configHeaterFan.heaterTemp, 60);
    expect(configHeaterFan.maxPower, 1);
    expect(configHeaterFan.kickStartTime, 0.5);
    expect(configHeaterFan.offBelow, 0);
    expect(configHeaterFan.cycleTime, 0.01);
    expect(configHeaterFan.hardwarePwm, false);
    expect(configHeaterFan.shutdownSpeed, 0);
    expect(configHeaterFan.pin, 'PD12');
    expect(configHeaterFan.fanSpeed, 1);
    expect(configHeaterFan.tachometerPin, 'PA2');
    expect(configHeaterFan.tachometerPpr, 4);
    expect(configHeaterFan.tachometerPollInterval, 0.3);
    expect(configHeaterFan.enablePin, 'PA1');
  });
}
