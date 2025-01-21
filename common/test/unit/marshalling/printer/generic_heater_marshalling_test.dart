/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
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
    });

  });
}

GenericHeater genericHeaterObject() {
  String input =
      '{"result": {"status": {"heater_generic Loool_Heater": {"temperature": 23.14, "power": 0.0, "target": 11.5}}, "eventtime": 4682073.267428618}}';

  var parsedJson = objectFromHttpApiResult(input, 'heater_generic Loool_Heater');

  return GenericHeater.fromJson({...parsedJson, 'name': 'TEST'});
}
