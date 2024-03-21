/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/config/led/config_dotstar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConfigDotstar.fromJson()', () {
    const neopixelStr = '''
   {
    "data_pin": "PD15",
    "clock_pin": "PB11",
    "chain_count": 1,
    "initial_red": 0.2,
    "initial_green": 0,
    "initial_blue": 0,
    "initial_white": 0
  }
    ''';
    var neopixelJson = jsonDecode(neopixelStr);

    var configDotstars = ConfigDotstar.fromJson('case_dotstars', neopixelJson);

    expect(configDotstars, isNotNull);
    expect(configDotstars.name, 'case_dotstars');
    expect(configDotstars.dataPin, 'PD15');
    expect(configDotstars.chainCount, 1);
    expect(configDotstars.initialRed, 0.2);
    expect(configDotstars.initialGreen, 0);
    expect(configDotstars.initialBlue, 0);
  });

  test('ConfigDotstar.fromJson() missing initial colors', () {
    const neopixelStr = '''
   {
    "data_pin": "PD15",
    "clock_pin": "PB11",
    "chain_count": 1
  }
    ''';
    var neopixelJson = jsonDecode(neopixelStr);

    var configDotstars = ConfigDotstar.fromJson('case_dotstars', neopixelJson);

    expect(configDotstars, isNotNull);
    expect(configDotstars.name, 'case_dotstars');
    expect(configDotstars.dataPin, 'PD15');
    expect(configDotstars.chainCount, 1);
    expect(configDotstars.initialRed, 0);
    expect(configDotstars.initialGreen, 0);
    expect(configDotstars.initialBlue, 0);
  });
}
