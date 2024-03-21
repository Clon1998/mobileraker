/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/config/config_stepper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Parse stepper config without gear_ratio', () {
    String input =
        '{"microsteps":32,"step_pin":"PF13","dir_pin":"!PF12","rotation_distance":40,"full_steps_per_rotation":400,"gear_ratio":[],"enable_pin":"!PF14","endstop_pin":"!PG6","position_endstop":300,"position_min":-1,"position_max":300,"homing_speed":75,"second_homing_speed":15,"homing_retract_speed":75,"homing_retract_dist":5,"homing_positive_dir":true}';

    ConfigStepper obj = ConfigStepper.fromJson('left', jsonDecode(input));

    expect(obj, isNotNull);
    expect(obj.name, equals('left'));
    expect(obj.stepPin, equals('PF13'));
    expect(obj.dirPin, equals('!PF12'));
    expect(obj.rotationDistance, equals(40));
    expect(obj.microsteps, equals(32));
    expect(obj.fullStepsPerRotation, equals(400));
    expect(obj.gearRatio, isEmpty); // Empty list
    expect(obj.enablePin, equals('!PF14'));
    expect(obj.endstopPin, equals('!PG6'));
    expect(obj.positionEndstop, equals(300));
    expect(obj.positionMin, equals(-1));
    expect(obj.positionMax, equals(300));
    expect(obj.homingSpeed, equals(75));
    expect(obj.secondHomingSpeed, equals(15));
    expect(obj.homingRetractSpeed, equals(75));
    expect(obj.homingRetractDist, equals(5));
    expect(obj.homingPositiveDir, equals(true));
  });

  test('Parse stepper config with gear_ratio', () {
    String input =
        '{"microsteps":128,"step_pin":"PF9","dir_pin":"!PF10","rotation_distance":40,"full_steps_per_rotation":200,"gear_ratio":[[80,16]],"enable_pin":"!PG2","endstop_pin":"probe:z_virtual_endstop","position_min":-2.5,"position_max":265,"homing_speed":15,"second_homing_speed":1,"homing_retract_speed":15,"homing_retract_dist":2,"homing_positive_dir":false}';

    ConfigStepper obj = ConfigStepper.fromJson('left', jsonDecode(input));

    expect(obj, isNotNull);
    expect(obj.name, equals('left'));
    expect(obj.stepPin, equals('PF9'));
    expect(obj.dirPin, equals('!PF10'));
    expect(obj.rotationDistance, equals(40));
    expect(obj.microsteps, equals(128));
    expect(obj.fullStepsPerRotation, equals(200));
    expect(obj.gearRatio, hasLength(2));
    expect(obj.gearRatio, equals([80, 16]));
    expect(obj.enablePin, equals('!PG2'));
    expect(obj.endstopPin, equals('probe:z_virtual_endstop'));
    expect(obj.positionMin, equals(-2.5));
    expect(obj.positionMax, equals(265));
    expect(obj.homingSpeed, equals(15));
    expect(obj.secondHomingSpeed, equals(1));
    expect(obj.homingRetractSpeed, equals(15));
    expect(obj.homingRetractDist, equals(2));
    expect(obj.homingPositiveDir, equals(false));
  });
}
