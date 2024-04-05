/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/leds/addressable_led.dart';
import 'package:common/data/dto/machine/leds/led.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

void main() {
  test('AddressableLed fromJson', () {
    AddressableLed obj = addressableLedObject();

    expect(obj, isNotNull);
    expect(obj.name, equals('sb_leds'));
    expect(
        obj.pixels,
        orderedEquals([
          Pixel.fromList([0.44, 0.0, 0.10, 0.20]),
          Pixel.fromList([0.0, 0.42, 0.69, 0.0]),
          Pixel.fromList([0.0, 0.88, 0.0, 0.11])
        ]));
  });
  test('AddressableLed partialUpdate from Led', () {
    AddressableLed old = addressableLedObject();

    var updateJson = {
      'color_data': [
        [0.88, 0.2, 0.55, 0.12],
        [0.42, 0.0, 0.69, 0.2],
      ]
    };

    var updatedObj = Led.partialUpdate(old, updateJson);

    expect(updatedObj, isNotNull);
    expect(updatedObj.name, equals('sb_leds'));
    expect(updatedObj is AddressableLed, isTrue);
    expect(
        (updatedObj as AddressableLed).pixels,
        orderedEquals([
          Pixel.fromList([0.88, 0.2, 0.55, 0.12]),
          Pixel.fromList([0.42, 0.0, 0.69, 0.2])
        ]));
  });

  test('AddressableLed partialUpdate - pixels', () {
    AddressableLed old = addressableLedObject();

    var updateJson = {
      'color_data': [
        [0.88, 0.2, 0.55, 0.12],
        [0.42, 0.0, 0.69, 0.2],
      ]
    };

    var updatedObj = AddressableLed.partialUpdate(old, updateJson);

    expect(updatedObj, isNotNull);
    expect(updatedObj.name, equals('sb_leds'));
    expect(
        updatedObj.pixels,
        orderedEquals([
          Pixel.fromList([0.88, 0.2, 0.55, 0.12]),
          Pixel.fromList([0.42, 0.0, 0.69, 0.2])
        ]));
  });

  test('AddressableLed fromJson, color_data map (Klipper < 11.x)', () {
    AddressableLed obj = legacyAddressableLedObject();

    expect(obj, isNotNull);
    expect(obj.name, equals('sb_leds'));
    expect(obj.name, equals('sb_leds'));
    expect(
        obj.pixels,
        orderedEquals([
          const Pixel(red: 0.44, green: 0.0, blue: 0.10, white: 0.20, legacy: true),
          const Pixel(red: 0.0, green: 0.42, blue: 0.69, white: 0.0, legacy: true),
          const Pixel(red: 0.0, green: 0.88, blue: 0.0, white: 0.11, legacy: true)
        ]));
  });
}

AddressableLed addressableLedObject() {
  String input =
      '{"result": {"status": {"neopixel sb_leds": {"color_data": [[0.44, 0.0, 0.10, 0.20], [0.0, 0.42, 0.69, 0.0], [0.0, 0.88, 0.0, 0.11]]}}, "eventtime": 4327798.835161627}}';

  var jsonRaw = objectFromHttpApiResult(input, 'neopixel sb_leds');

  return AddressableLed.fromJson(jsonRaw, 'sb_leds');
}

AddressableLed legacyAddressableLedObject() {
  String input =
      '{"result": {"status": {"neopixel sb_leds": {"color_data": [{"R":0.44,"G":0.0,"B":0.10,"W": 0.20},{"R":0.0,"G":0.42,"B":0.69},{"R":0.0,"G":0.88,"B":0.0,"W": 0.11}]}}, "eventtime": 4327798.835161627}}';

  var jsonRaw = objectFromHttpApiResult(input, 'neopixel sb_leds');

  return AddressableLed.fromJson(jsonRaw, 'sb_leds');
}
