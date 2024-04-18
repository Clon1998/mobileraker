/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/config/config_screws_tilt_adjust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConfigScrewsTiltAdjust.fromJson() three screws', () {
    const str = '''
{
  "screw1": [
    5,
    30
  ],
  "screw1_name": "front left screw",
  "screw2": [
    155,
    30
  ],
  "screw2_name": "front right screw",
  "screw3": [
    155,
    190
  ],
  "screw3_name": "rear right screw",
  "screw_thread": "CW-M3",
  "horizontal_move_z": 10,
  "speed": 50
}
    ''';
    var strToJson = jsonDecode(str);

    var configSTA = ConfigScrewsTiltAdjust.fromJson(strToJson);

    expect(configSTA, isNotNull);
    expect(configSTA.horizontalMoveZ, 10);
    expect(configSTA.speed, 50);
    expect(configSTA.screwThread, 'CW-M3');

    // Verify screws
    expect(configSTA.screws.length, 3);
    expect(configSTA.screws[0].x, 5);
    expect(configSTA.screws[0].y, 30);
    expect(configSTA.screws[0].name, 'front left screw');

    expect(configSTA.screws[1].x, 155);
    expect(configSTA.screws[1].y, 30);
    expect(configSTA.screws[1].name, 'front right screw');

    expect(configSTA.screws[2].x, 155);
    expect(configSTA.screws[2].y, 190);
    expect(configSTA.screws[2].name, 'rear right screw');
  });
  //
  //  test('ConfigBedScrews.fromJson() 1 screws', () {
  //    const str = '''
  // {
  //    "screw1": [
  //      100,
  //      50
  //    ],
  //    "screw1_name": "screw at 100.000,50.000",
  //    "speed": 50,
  //    "probe_speed": 5,
  //    "horizontal_move_z": 5,
  //    "probe_height": 0
  //  }
  //    ''';
  //    var strToJson = jsonDecode(str);
  //
  //    var configBedScrew = ConfigBedScrews.fromJson(strToJson);
  //
  //    expect(configBedScrew, isNotNull);
  //    expect(configBedScrew.horizontalMoveZ, 5);
  //    expect(configBedScrew.probeHeight, 0);
  //    expect(configBedScrew.probeSpeed, 5);
  //    expect(configBedScrew.speed, 50);
  //    expect(configBedScrew.screws.length, 1);
  //  });
}
