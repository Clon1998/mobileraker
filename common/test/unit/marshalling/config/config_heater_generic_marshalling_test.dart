/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/config/config_heater_generic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConfigHeaterGeneric.fromJson() non PWM', () {
    const str = '''
  {
    "control": "bangbang",
    "heater_pin": "PA11",
    "sensor_pin": "PV1",
    "sensor_type": "MAX31855",
    "max_power": 0.5,
    "max_temp": 250,
    "min_temp": 100
  }
    ''';
    var strToJson = jsonDecode(str);

    var configHeaterGeneric = ConfigHeaterGeneric.fromJson('exhaust_fan', strToJson);

    expect(configHeaterGeneric, isNotNull);
    expect(configHeaterGeneric.control, 'bangbang');
    expect(configHeaterGeneric.name, 'exhaust_fan');
    expect(configHeaterGeneric.heaterPin, 'PA11');
    expect(configHeaterGeneric.sensorPin, 'PV1');
    expect(configHeaterGeneric.sensorType, 'MAX31855');
    expect(configHeaterGeneric.maxPower, 0.5);
    expect(configHeaterGeneric.maxTemp, 250);
    expect(configHeaterGeneric.minTemp, 100);
  });

  test('ConfigHeaterGeneric.fromJson() combined sensor', () {
    const str = '''
  {
    "control": "bangbang",
    "heater_pin": "PA11",
    "sensor_pin": "PV1",
    "sensor_type": "temperature_combined",
    "sensor_list": "one two three",
    "max_power": 0.5,
    "max_temp": 250,
    "min_temp": 100
  }
    ''';
    var strToJson = jsonDecode(str);

    var configHeaterGeneric = ConfigHeaterGeneric.fromJson('exhaust_fan', strToJson);

    expect(configHeaterGeneric, isNotNull);
    expect(configHeaterGeneric.control, 'bangbang');
    expect(configHeaterGeneric.name, 'exhaust_fan');
    expect(configHeaterGeneric.heaterPin, 'PA11');
    expect(configHeaterGeneric.sensorPin, 'PV1');
    expect(configHeaterGeneric.sensorType, 'temperature_combined');
    expect(configHeaterGeneric.maxPower, 0.5);
    expect(configHeaterGeneric.maxTemp, 250);
    expect(configHeaterGeneric.minTemp, 100);
  });
}
