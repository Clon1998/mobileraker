/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/leds/dumb_led.dart';
import 'package:common/data/dto/machine/leds/led.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

void main() {
  test('DumbLed fromJson', () {
    DumbLed obj = dumbLedObject();

    expect(obj, isNotNull);
    expect(obj.name, equals('caselight'));
    expect(obj.color, equals(const Pixel(red: 1, green: 1, blue: 0.11, white: 0.44)));
  });
  test('DumbLed partialUpdate from Led', () {
    DumbLed old = dumbLedObject();

    var updateJson = {
      'color_data': [
        [0.88, 0.2, 0.55, 0.12]
      ]
    };

    var updatedObj = Led.partialUpdate(old, updateJson);

    expect(updatedObj, isNotNull);
    expect(updatedObj.name, equals('caselight'));
    expect(updatedObj is DumbLed, isTrue);
    expect((updatedObj as DumbLed).color, equals(Pixel.fromList([0.88, 0.2, 0.55, 0.12])));
  });
  test('DumbLed partialUpdate - color', () {
    DumbLed old = dumbLedObject();

    var updateJson = {
      'color_data': [
        [0.88, 0.2, 0.55, 0.12]
      ]
    };

    var updatedObj = DumbLed.partialUpdate(old, updateJson);

    expect(updatedObj, isNotNull);
    expect(updatedObj.name, equals('caselight'));
    expect(updatedObj.color, equals(Pixel.fromList([0.88, 0.2, 0.55, 0.12])));
  });
}

DumbLed dumbLedObject() {
  String input =
      '{"result": {"status": {"led caselight": {"color_data": [[1.0, 1.0, 0.11, 0.44]]}}, "eventtime": 4328671.506395617}}';

  var jsonRaw = objectFromHttpApiResult(input, 'led caselight');

  return DumbLed.fromJson(jsonRaw, 'caselight');
}
