/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/config/config_printer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConfigPrinter.fromJson()', () {
    const jsonString = '''
{
    "max_velocity": 500,
    "max_accel": 7000,
    "max_accel_to_decel": 3500,
    "square_corner_velocity": 8,
    "buffer_time_low": 1,
    "buffer_time_high": 2,
    "buffer_time_start": 0.25,
    "move_flush_time": 0.05,
    "kinematics": "corexy",
    "max_z_velocity": 30,
    "max_z_accel": 350
  }
      ''';

    final jsonMap = json.decode(jsonString);
    final configPrinter = ConfigPrinter.fromJson(jsonMap);
    expect(configPrinter.kinematics, 'corexy');
    expect(configPrinter.maxVelocity, 500);
    expect(configPrinter.maxAccel, 7000);
    expect(configPrinter.maxAccelToDecel, 3500);
    expect(configPrinter.squareCornerVelocity, 8);
  });
}
