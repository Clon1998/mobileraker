/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/heaters/generic_heater.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

var NOW = DateTime.now();

void main() {
  test('GenericHeater fromJson', () {
    var genericHeater = genericHeaterObject();

    expect(genericHeater, isNotNull);
    expect(genericHeater.temperature, equals(23.14));
    expect(genericHeater.target, equals(11.5));
    expect(genericHeater.power, equals(0));
    expect(genericHeater.lastHistory, equals(NOW));
    expect(genericHeater.temperatureHistory, isNull);
    expect(genericHeater.targetHistory, isNull);
    expect(genericHeater.powerHistory, isNull);
  });

  group('GenericHeater partialUpdate', () {
    test('power', () {
      var old = genericHeaterObject();
      var parsedJson = {
        'power': 1.0,
      };

      var updated = GenericHeater.partialUpdate(old, parsedJson);

      expect(updated, isNotNull);
      expect(updated.temperature, equals(23.14));
      expect(updated.target, equals(11.5));
      expect(updated.power, equals(1));
      expect(updated.lastHistory, equals(NOW));
      expect(updated.temperatureHistory, isNull);
      expect(updated.targetHistory, isNull);
      expect(updated.powerHistory, isNull);
    });

    test('temperature', () {
      var old = genericHeaterObject();
      var parsedJson = {
        'temperature': 224.5,
      };

      var updated = GenericHeater.partialUpdate(old, parsedJson);

      expect(updated, isNotNull);
      expect(updated.temperature, equals(224.5));
      expect(updated.target, equals(11.5));
      expect(updated.power, equals(0));
      expect(updated.lastHistory, equals(NOW));
      expect(updated.temperatureHistory, isNull);
      expect(updated.targetHistory, isNull);
      expect(updated.powerHistory, isNull);
    });

    test('target', () {
      var old = genericHeaterObject();
      var parsedJson = {
        'target': 114.5,
      };

      var updated = GenericHeater.partialUpdate(old, parsedJson);

      expect(updated, isNotNull);
      expect(updated.temperature, equals(23.14));
      expect(updated.target, equals(114.5));
      expect(updated.power, equals(0));
      expect(updated.lastHistory, equals(NOW));
      expect(updated.temperatureHistory, isNull);
      expect(updated.targetHistory, isNull);
      expect(updated.powerHistory, isNull);
    });

    test('temperature Histories', () {
      var old = genericHeaterObject();

      var parsedJson = {
        'powers': [0, 0, 0, 0, 0.5, 0.9, 1.0],
        'temperatures': [30, 30, 31, 31, 32.5, 44, 45, 45, 9],
        'targets': [0, 0, 0, 1.4, 2, 3, 4, 5, 6, 7, 8, 8, 9],
      };

      var genericHeater = GenericHeater.partialUpdate(old, parsedJson);

      expect(genericHeater, isNotNull);
      expect(genericHeater.temperature, equals(23.14));
      expect(genericHeater.target, equals(11.5));
      expect(genericHeater.power, equals(0));
      expect(genericHeater.lastHistory, equals(NOW));

      expect(
          genericHeater.temperatureHistory, orderedEquals([30, 30, 31, 31, 32.5, 44, 45, 45, 9]));
      expect(genericHeater.targetHistory, orderedEquals([0, 0, 0, 1.4, 2, 3, 4, 5, 6, 7, 8, 8, 9]));
      expect(genericHeater.powerHistory, orderedEquals([0, 0, 0, 0, 0.5, 0.9, 1.0]));
    });
  });
}

GenericHeater genericHeaterObject() {
  String input =
      '{"result": {"status": {"heater_generic Loool_Heater": {"temperature": 23.14, "power": 0.0, "target": 11.5}}, "eventtime": 4682073.267428618}}';

  var parsedJson = objectFromHttpApiResult(input, 'heater_generic Loool_Heater');

  return GenericHeater.fromJson({...parsedJson, 'name': 'TEST', 'lastHistory': NOW.toIso8601String()});
}
