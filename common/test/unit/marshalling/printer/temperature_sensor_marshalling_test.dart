/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/temperature_sensor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

var NOW = DateTime.now();

void main() {
  test('TemperatureSensor fromJson', () {
    var obj = temperatureSensorObject();

    expect(obj, isNotNull);
    expect(obj.temperature, equals(42.39));
    expect(obj.measuredMinTemp, equals(39.7));
    expect(obj.measuredMaxTemp, equals(60.69));
    expect(obj.lastHistory, equals(NOW));
    expect(obj.temperatureHistory, isNull);
  });

  group('TemperatureSensor partialUpdate', () {
    test('temperature', () {
      var old = temperatureSensorObject();

      var parsedJson = {
        'temperature': 224.5,
      };

      var updatedObj = TemperatureSensor.partialUpdate(old, parsedJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.temperature, equals(224.5));
      expect(updatedObj.measuredMinTemp, equals(39.7));
      expect(updatedObj.measuredMaxTemp, equals(60.69));
      expect(updatedObj.lastHistory, equals(NOW));
      expect(updatedObj.temperatureHistory, isNull);
    });

    test('measured_min_temp', () {
      var old = temperatureSensorObject();

      var parsedJson = {
        'measured_min_temp': 5.22,
      };

      var updatedObj = TemperatureSensor.partialUpdate(old, parsedJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.temperature, equals(42.39));
      expect(updatedObj.measuredMinTemp, equals(5.22));
      expect(updatedObj.measuredMaxTemp, equals(60.69));
      expect(updatedObj.lastHistory, equals(NOW));
      expect(updatedObj.temperatureHistory, isNull);
    });

    test('measured_max_temp', () {
      var old = temperatureSensorObject();

      var parsedJson = {
        'measured_max_temp': 102.49,
      };

      var updatedObj = TemperatureSensor.partialUpdate(old, parsedJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.temperature, equals(42.39));
      expect(updatedObj.measuredMinTemp, equals(39.7));
      expect(updatedObj.measuredMaxTemp, equals(102.49));
      expect(updatedObj.lastHistory, equals(NOW));
      expect(updatedObj.temperatureHistory, isNull);
    });

    test('temperatureHistory', () {
      var old = temperatureSensorObject();

      var parsedJson = {
        'temperatures': [30, 30, 31, 31, 32.5, 44, 45, 45, 9],
      };

      var updatedObj = TemperatureSensor.partialUpdate(old, parsedJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.temperature, equals(42.39));
      expect(updatedObj.measuredMinTemp, equals(39.7));
      expect(updatedObj.measuredMaxTemp, equals(60.69));
      expect(updatedObj.lastHistory, equals(NOW));
      expect(updatedObj.temperatureHistory, orderedEquals([30, 30, 31, 31, 32.5, 44, 45, 45, 9]));
    });
  });
}

TemperatureSensor temperatureSensorObject() {
  String input =
      '{"result": {"status": {"temperature_sensor raspberry_pi": {"measured_min_temp": 39.7, "measured_max_temp": 60.69, "temperature": 42.39}}, "eventtime": 4231105.430276898}}';

  var parsedJson = objectFromHttpApiResult(input, 'temperature_sensor raspberry_pi');

  return TemperatureSensor.fromJson({...parsedJson, 'lastHistory': NOW.toIso8601String()}, 'raspberry_pi');
}
