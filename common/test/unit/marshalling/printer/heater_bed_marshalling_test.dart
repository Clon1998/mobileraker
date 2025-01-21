/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/heaters/heater_bed.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

var NOW = DateTime.now();

void main() {
  test('HeaterBed fromJson', () {
    var heaterBed = HeaterBedObject();

    expect(heaterBed, isNotNull);
    expect(heaterBed.temperature, equals(23.14));
    expect(heaterBed.target, equals(11.5));
    expect(heaterBed.power, equals(0));
  });

  test('HeaterBed partialUpdate', () {
    var old = HeaterBedObject();

    var parsedJson = {
      'power': 1.0,
      'temperature': 224.5,
    };

    var heaterBed = HeaterBed.partialUpdate(old, parsedJson);

    expect(heaterBed, isNotNull);
    expect(heaterBed.temperature, equals(224.5));
    expect(heaterBed.target, equals(11.5));
    expect(heaterBed.power, equals(1.0));
  });

}

HeaterBed HeaterBedObject() {
  String input =
      '{"result": {"status": {"heater_bed": {"temperature": 23.14, "power": 0.0, "target": 11.5}}, "eventtime": 3793416.674978863}}';

  var parsedJson = objectFromHttpApiResult(input, 'heater_bed');

  return HeaterBed.fromJson({...parsedJson});
}
