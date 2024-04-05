/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
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
    expect(heaterBed.lastHistory, equals(NOW));
    expect(heaterBed.temperatureHistory, isNull);
    expect(heaterBed.targetHistory, isNull);
    expect(heaterBed.powerHistory, isNull);
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
    expect(heaterBed.lastHistory, equals(NOW));
    expect(heaterBed.temperatureHistory, isNull);
    expect(heaterBed.targetHistory, isNull);
    expect(heaterBed.powerHistory, isNull);
  });

  test('HeaterBed partialUpdate - temperature History', () {
    var old = HeaterBedObject();

    var parsedJson = {
      'powers': [0, 0, 0, 0, 0.5, 0.9, 1.0],
      'temperatures': [30, 30, 31, 31, 32.5, 44, 45, 45, 9],
      'targets': [0, 0, 0, 1.4, 2, 3, 4, 5, 6, 7, 8, 8, 9],
    };

    var heaterBed = HeaterBed.partialUpdate(old, parsedJson);

    expect(heaterBed, isNotNull);
    expect(heaterBed.temperature, equals(23.14));
    expect(heaterBed.target, equals(11.5));
    expect(heaterBed.power, equals(0));
    expect(heaterBed.lastHistory, equals(NOW));

    expect(heaterBed.temperatureHistory, orderedEquals([30, 30, 31, 31, 32.5, 44, 45, 45, 9]));
    expect(heaterBed.targetHistory, orderedEquals([0, 0, 0, 1.4, 2, 3, 4, 5, 6, 7, 8, 8, 9]));
    expect(heaterBed.powerHistory, orderedEquals([0, 0, 0, 0, 0.5, 0.9, 1.0]));
  });
}

HeaterBed HeaterBedObject() {
  String input =
      '{"result": {"status": {"heater_bed": {"temperature": 23.14, "power": 0.0, "target": 11.5}}, "eventtime": 3793416.674978863}}';

  var parsedJson = objectFromHttpApiResult(input, 'heater_bed');

  return HeaterBed.fromJson({...parsedJson, 'lastHistory': NOW.toIso8601String()});
}
