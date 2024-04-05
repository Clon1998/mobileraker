/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/config/config_extruder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConfigExtruder.fromJson() creates ConfigExtruder instance from JSON', () {
    const jsonString = '''
        {
            "microsteps": 64,
            "sensor_type": "ATC Semitec 104GT-2",
            "pullup_resistor": 4700,
            "inline_resistor": 0,
            "sensor_pin": "PF4",
            "min_temp": 10,
            "max_temp": 300,
            "min_extrude_temp": 140,
            "max_power": 1,
            "smooth_time": 0.5,
            "control": "pid",
            "pid_kp": 31.336,
            "pid_ki": 2.517,
            "pid_kd": 97.533,
            "heater_pin": "PA2",
            "pwm_cycle_time": 0.1,
            "nozzle_diameter": 0.4,
            "filament_diameter": 1.75,
            "max_extrude_cross_section": 50,
            "max_extrude_only_velocity": 133.5,
            "max_extrude_only_accel": 1862.5,
            "max_extrude_only_distance": 200,
            "instantaneous_corner_velocity": 1,
            "step_pin": "PG4",
            "pressure_advance": 0.055,
            "pressure_advance_smooth_time": 0.04,
            "dir_pin": "!PC1",
            "rotation_distance": 8,
            "full_steps_per_rotation": 200,
            "gear_ratio": [],
            "enable_pin": "!PA0"
          }
      ''';

    final jsonMap = json.decode(jsonString);
    final configExtruder = ConfigExtruder.fromJson('test_name', jsonMap);

    expect(configExtruder.name, 'test_name');
    expect(configExtruder.nozzleDiameter, 0.4);
    expect(configExtruder.maxExtrudeOnlyDistance, 200);
    expect(configExtruder.minTemp, 10);
    expect(configExtruder.minExtrudeTemp, 140);
    expect(configExtruder.maxTemp, 300);
    expect(configExtruder.maxPower, 1);
    expect(configExtruder.filamentDiameter, 1.75);
    expect(configExtruder.maxExtrudeOnlyVelocity, 133.5);
    expect(configExtruder.maxExtrudeOnlyAccel, 1862.5);
  });

  test('ConfigExtruder.fromJson() creates ConfigExtruder instance from JSON with combined sensor', () {
    const jsonString = '''
        {
            "microsteps": 64,
            "sensor_type": "ATC Semitec 104GT-2",
            "pullup_resistor": 4700,
            "inline_resistor": 0,
            "sensor_type": "temperature_combined",
            "sensor_list": "one two three",
            "min_temp": 10,
            "max_temp": 300,
            "min_extrude_temp": 140,
            "max_power": 1,
            "smooth_time": 0.5,
            "control": "pid",
            "pid_kp": 31.336,
            "pid_ki": 2.517,
            "pid_kd": 97.533,
            "heater_pin": "PA2",
            "pwm_cycle_time": 0.1,
            "nozzle_diameter": 0.4,
            "filament_diameter": 1.75,
            "max_extrude_cross_section": 50,
            "max_extrude_only_velocity": 133.5,
            "max_extrude_only_accel": 1862.5,
            "max_extrude_only_distance": 200,
            "instantaneous_corner_velocity": 1,
            "step_pin": "PG4",
            "pressure_advance": 0.055,
            "pressure_advance_smooth_time": 0.04,
            "dir_pin": "!PC1",
            "rotation_distance": 8,
            "full_steps_per_rotation": 200,
            "gear_ratio": [],
            "enable_pin": "!PA0"
          }
      ''';

    final jsonMap = json.decode(jsonString);
    final configExtruder = ConfigExtruder.fromJson('test_name', jsonMap);

    expect(configExtruder.name, 'test_name');
    expect(configExtruder.nozzleDiameter, 0.4);
    expect(configExtruder.maxExtrudeOnlyDistance, 200);
    expect(configExtruder.minTemp, 10);
    expect(configExtruder.minExtrudeTemp, 140);
    expect(configExtruder.maxTemp, 300);
    expect(configExtruder.maxPower, 1);
    expect(configExtruder.filamentDiameter, 1.75);
    expect(configExtruder.maxExtrudeOnlyVelocity, 133.5);
    expect(configExtruder.maxExtrudeOnlyAccel, 1862.5);
  });
}
