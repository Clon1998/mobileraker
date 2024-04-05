/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/config/config_heater_bed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConfigHeaterBed.fromJson() ', () {
    const jsonString = '''
 {
    "sensor_type": "NTC 100K MGB18-104F39050L32",
    "pullup_resistor": 4700,
    "inline_resistor": 0,
    "sensor_pin": "PF3",
    "min_temp": 15,
    "max_temp": 120,
    "min_extrude_temp": 170,
    "max_power": 0.6,
    "smooth_time": 1,
    "control": "pid",
    "pid_kp": 40.598,
    "pid_ki": 1.395,
    "pid_kd": 295.352,
    "heater_pin": "PD13",
    "pwm_cycle_time": 0.1
  }
      ''';

    final jsonMap = json.decode(jsonString);
    final configHeaterBed = ConfigHeaterBed.fromJson(jsonMap);
    expect(configHeaterBed.heaterPin, 'PD13');
    expect(configHeaterBed.sensorType, 'NTC 100K MGB18-104F39050L32');
    expect(configHeaterBed.sensorPin, 'PF3');
    expect(configHeaterBed.control, 'pid');
    expect(configHeaterBed.minTemp, 15);
    expect(configHeaterBed.maxTemp, 120);
    expect(configHeaterBed.maxPower, 0.6);
  });

  test('ConfigHeaterBed.fromJson() with combined sensor', () {
    const jsonString = '''
 {
    "sensor_type": "temperature_combined",
    "sensor_list": "one two three",
    "pullup_resistor": 4700,
    "inline_resistor": 0,
    "sensor_pin": "PF3",
    "min_temp": 15,
    "max_temp": 120,
    "min_extrude_temp": 170,
    "max_power": 0.6,
    "smooth_time": 1,
    "control": "pid",
    "pid_kp": 40.598,
    "pid_ki": 1.395,
    "pid_kd": 295.352,
    "heater_pin": "PD13",
    "pwm_cycle_time": 0.1
  }
      ''';

    final jsonMap = json.decode(jsonString);
    final configHeaterBed = ConfigHeaterBed.fromJson(jsonMap);
    expect(configHeaterBed.heaterPin, 'PD13');
    expect(configHeaterBed.sensorType, 'temperature_combined');
    expect(configHeaterBed.sensorPin, 'PF3');
    expect(configHeaterBed.control, 'pid');
    expect(configHeaterBed.minTemp, 15);
    expect(configHeaterBed.maxTemp, 120);
    expect(configHeaterBed.maxPower, 0.6);
  });
}
