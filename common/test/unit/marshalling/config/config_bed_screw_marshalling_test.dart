/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/config/config_bed_screws.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConfigBedScrews.fromJson() three screws', () {
    const str = '''
 {
    "screw1": [
      100,
      50
    ],
    "screw1_name": "screw at 100.000,50.000",
    "screw2": [
      100,
      150
    ],
    "screw2_name": "screw at 100.000,150.000",
    "screw3": [
      150,
      100
    ],
    "screw3_name": "screw at 150.000,100.000",
    "speed": 50,
    "probe_speed": 5,
    "horizontal_move_z": 5,
    "probe_height": 0
  }
    ''';
    var strToJson = jsonDecode(str);

    var configBedScrew = ConfigBedScrews.fromJson(strToJson);

    expect(configBedScrew, isNotNull);
    expect(configBedScrew.horizontalMoveZ, 5);
    expect(configBedScrew.probeHeight, 0);
    expect(configBedScrew.probeSpeed, 5);
    expect(configBedScrew.speed, 50);
    expect(configBedScrew.screws.length, 3);
  });

  test('ConfigBedScrews.fromJson() 1 screws', () {
    const str = '''
 {
    "screw1": [
      100,
      50
    ],
    "screw1_name": "screw at 100.000,50.000",    
    "speed": 50,
    "probe_speed": 5,
    "horizontal_move_z": 5,
    "probe_height": 0
  }
    ''';
    var strToJson = jsonDecode(str);

    var configBedScrew = ConfigBedScrews.fromJson(strToJson);

    expect(configBedScrew, isNotNull);
    expect(configBedScrew.horizontalMoveZ, 5);
    expect(configBedScrew.probeHeight, 0);
    expect(configBedScrew.probeSpeed, 5);
    expect(configBedScrew.speed, 50);
    expect(configBedScrew.screws.length, 1);
  });
}
