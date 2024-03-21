/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/config/led/config_pca_led.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConfigPcaLed.fromJson()', () {
    const str = '''
  {
    "initial_red": 0,
    "initial_green": 0.2,
    "initial_blue": 0,
    "initial_white": 0
  }
    ''';
    var strToJson = jsonDecode(str);

    var configDumpLed = ConfigPcaLed.fromJson('caselight', strToJson);

    expect(configDumpLed, isNotNull);
    expect(configDumpLed.name, 'caselight');
    expect(configDumpLed.initialRed, 0);
    expect(configDumpLed.initialGreen, 0.2);
    expect(configDumpLed.initialBlue, 0);
    expect(configDumpLed.initialWhite, 0);
  });

  test('ConfigPcaLed.fromJson() missing colors', () {
    const str = '''
  {

  }
    ''';
    var strToJson = jsonDecode(str);

    var configDumpLed = ConfigPcaLed.fromJson('caselight', strToJson);

    expect(configDumpLed, isNotNull);
    expect(configDumpLed.name, 'caselight');
    expect(configDumpLed.initialRed, 0);
    expect(configDumpLed.initialGreen, 0);
    expect(configDumpLed.initialBlue, 0);
    expect(configDumpLed.initialWhite, 0);
  });
}
