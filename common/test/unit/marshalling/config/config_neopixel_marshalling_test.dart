/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/config/led/config_neopixel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConfigNeopixel.fromJson()', () {
    const neopixelStr = '''
    {
      "pin": "EXP1_6",
      "chain_count": 3,
      "color_order": [
        "RGB"
      ],
      "initial_red": 1,
      "initial_green": 1,
      "initial_blue": 1,
      "initial_white": 0
    }
    ''';
    var neopixelJson = jsonDecode(neopixelStr);

    var configNeopixel = ConfigNeopixel.fromJson('fysetc_mini12864', neopixelJson);

    expect(configNeopixel, isNotNull);
    expect(configNeopixel.name, 'fysetc_mini12864');
    expect(configNeopixel.pin, 'EXP1_6');
    expect(configNeopixel.colorOrder, 'RGB');
    expect(configNeopixel.chainCount, 3);
    expect(configNeopixel.initialRed, 1.0);
    expect(configNeopixel.initialGreen, 1.0);
    expect(configNeopixel.initialBlue, 1.0);
    expect(configNeopixel.initialWhite, 0);
  });

  test('ConfigNeopixel.fromJson() without inital color fields', () {
    const neopixelStr = '''
    {
      "pin": "EXP1_6",
      "chain_count": 3,
      "color_order": [
        "RGB"
      ]
    }
    ''';
    var neopixelJson = jsonDecode(neopixelStr);

    var configNeopixel = ConfigNeopixel.fromJson('fysetc_mini12864', neopixelJson);

    expect(configNeopixel, isNotNull);
    expect(configNeopixel.pin, 'EXP1_6');
    expect(configNeopixel.colorOrder, 'RGB');
    expect(configNeopixel.chainCount, 3);
    expect(configNeopixel.initialRed, 0);
    expect(configNeopixel.initialGreen, 0);
    expect(configNeopixel.initialBlue, 0);
    expect(configNeopixel.initialWhite, 0);
  });

  test('ConfigNeopixel.fromJson(), color_order as String (Klipper < 11.x)', () {
    const neopixelStr = '''
    {
      "pin": "EXP1_6",
      "chain_count": 3,
      "color_order": "RGB",
      "initial_red": 1,
      "initial_green": 1,
      "initial_blue": 1,
      "initial_white": 0
    }
    ''';
    var neopixelJson = jsonDecode(neopixelStr);

    var configNeopixel = ConfigNeopixel.fromJson('fysetc_mini12864', neopixelJson);

    expect(configNeopixel, isNotNull);
    expect(configNeopixel.name, 'fysetc_mini12864');
    expect(configNeopixel.pin, 'EXP1_6');
    expect(configNeopixel.colorOrder, 'RGB');
    expect(configNeopixel.chainCount, 3);
    expect(configNeopixel.initialRed, 1.0);
    expect(configNeopixel.initialGreen, 1.0);
    expect(configNeopixel.initialBlue, 1.0);
    expect(configNeopixel.initialWhite, 0);
  });
}
