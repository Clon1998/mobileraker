/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
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
    });

  });
}

TemperatureSensor temperatureSensorObject() {
  String input =
      '{"result": {"status": {"temperature_sensor raspberry_pi": {"measured_min_temp": 39.7, "measured_max_temp": 60.69, "temperature": 42.39}}, "eventtime": 4231105.430276898}}';

  var parsedJson = objectFromHttpApiResult(input, 'temperature_sensor raspberry_pi');

  return TemperatureSensor.fromJson({...parsedJson}, 'raspberry_pi');
}
