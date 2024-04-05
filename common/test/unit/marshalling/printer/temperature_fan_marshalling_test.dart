/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/fans/temperature_fan.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

var NOW = DateTime.now();

void main() {
  test('TemperatureFan with RPM fromJson', () {
    TemperatureFan obj = temperatureFanObjectWithRpm();

    expect(obj, isNotNull);
    expect(obj.speed, equals(0.55));
    expect(obj.rpm, equals(500));
    expect(obj.temperature, equals(11.1));
    expect(obj.target, equals(44.95));
    expect(obj.lastHistory, equals(NOW));
  });

  test('TemperatureFan without RPM fromJson', () {
    TemperatureFan obj = temperatureFanObjectWithoutRpm();

    expect(obj, isNotNull);
    expect(obj.speed, equals(0.55));
    expect(obj.rpm, equals(null));
    expect(obj.temperature, equals(11.1));
    expect(obj.target, equals(44.95));
    expect(obj.lastHistory, equals(NOW));
  });

  group('TemperatureFan partialUpdate', () {
    test('speed', () {
      TemperatureFan old = temperatureFanObjectWithRpm();

      var updateJson = {'speed': 0.99};

      var updatedObj = TemperatureFan.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.speed, equals(0.99));
      expect(updatedObj.rpm, equals(500));
      expect(updatedObj.temperature, equals(11.1));
      expect(updatedObj.target, equals(44.95));
      expect(updatedObj.lastHistory, equals(NOW));
    });

    test('rpm', () {
      TemperatureFan old = temperatureFanObjectWithRpm();

      var updateJson = {'rpm': 1099};

      var updatedObj = TemperatureFan.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.speed, equals(0.55));
      expect(updatedObj.rpm, equals(1099));
      expect(updatedObj.temperature, equals(11.1));
      expect(updatedObj.target, equals(44.95));
      expect(updatedObj.lastHistory, equals(NOW));
    });

    test('temperature', () {
      TemperatureFan old = temperatureFanObjectWithRpm();

      var updateJson = {'temperature': 99};

      var updatedObj = TemperatureFan.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.speed, equals(0.55));
      expect(updatedObj.rpm, equals(500));
      expect(updatedObj.temperature, equals(99));
      expect(updatedObj.target, equals(44.95));
      expect(updatedObj.lastHistory, equals(NOW));
    });

    test('target', () {
      TemperatureFan old = temperatureFanObjectWithRpm();

      var updateJson = {'target': 85.22};

      var updatedObj = TemperatureFan.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.speed, equals(0.55));
      expect(updatedObj.rpm, equals(500));
      expect(updatedObj.temperature, equals(11.1));
      expect(updatedObj.target, equals(85.22));
      expect(updatedObj.lastHistory, equals(NOW));
    });
  });
}

TemperatureFan temperatureFanObjectWithRpm() {
  String input =
      '{"result": {"status": {"fan": {"speed": 0.55, "rpm": 500, "temperature":11.1, "target": 44.95}}, "eventtime": 3801252.15548827}}';

  var jsonRaw = objectFromHttpApiResult(input, 'fan');

  return TemperatureFan.fromJson({...jsonRaw, 'lastHistory': NOW.toIso8601String()}, 'testFan');
}

TemperatureFan temperatureFanObjectWithoutRpm() {
  String input =
      '{"result": {"status": {"fan": {"speed": 0.55, "rpm": null, "temperature":11.1, "target": 44.95}}, "eventtime": 3801252.15548827}}';

  var jsonRaw = objectFromHttpApiResult(input, 'fan');

  return TemperatureFan.fromJson({...jsonRaw, 'lastHistory': NOW.toIso8601String()}, 'testFan');
}
