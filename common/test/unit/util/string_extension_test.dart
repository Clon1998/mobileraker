/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
import 'package:common/util/extensions/string_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MobilerakerString', () {



    // Tests for toKlipperObjectIdentifierNEW
    test('toKlipperObjectIdentifierNEW returns ConfigFileObjectIdentifiers and null when single word', () {
      final result = 'Temperature_Sensor'.toKlipperObjectIdentifierNEW();
      expect(result, (ConfigFileObjectIdentifiers.temperature_sensor, null));
    });

    test('toKlipperObjectIdentifierNEW returns ConfigFileObjectIdentifiers and trimmed object name when multiple words',
        () {
      final result = 'Temperature_Sensor sensor_name'.toKlipperObjectIdentifierNEW();
      expect(result, (ConfigFileObjectIdentifiers.temperature_sensor, 'sensor_name'));
    });

    test('toKlipperObjectIdentifierNEW handles leading and trailing whitespaces', () {
      final result = '  Temperature_Sensor sensor_name  '.toKlipperObjectIdentifierNEW();
      expect(result, (ConfigFileObjectIdentifiers.temperature_sensor, 'sensor_name'));
    });

    test('toKlipperObjectIdentifierNEW handles multiple whitespaces between words', () {
      final result = 'Temperature_Sensor    sensor_name'.toKlipperObjectIdentifierNEW();
      expect(result, (ConfigFileObjectIdentifiers.temperature_sensor, 'sensor_name'));
    });

    test('toKlipperObjectIdentifierNEW handles multiple sections with whitespaces', () {
      final result = 'Temperature_Sensor sensor_name extra_part'.toKlipperObjectIdentifierNEW();
      expect(result, (ConfigFileObjectIdentifiers.temperature_sensor, 'sensor_name extra_part'));
    });

    test('toKlipperObjectIdentifierNEW handles multiple sections with multiple whitespaces', () {
      final result = 'Temperature_Sensor    sensor_name    extra_part'.toKlipperObjectIdentifierNEW();
      expect(result, (ConfigFileObjectIdentifiers.temperature_sensor, 'sensor_name    extra_part'));
    });

    test('toKlipperObjectIdentifierNEW returns (null, null) when identifier is not recognized', () {
      final result = 'Unknown_Identifier'.toKlipperObjectIdentifierNEW();
      expect(result, (null, null));
    });

    test('toKlipperObjectIdentifierNEW handles identifiers that use regex', () {
      var result = 'extruder1'.toKlipperObjectIdentifierNEW();
      expect(result, (ConfigFileObjectIdentifiers.extruder, null));
      result = 'extruder'.toKlipperObjectIdentifierNEW();
      expect(result, (ConfigFileObjectIdentifiers.extruder, null));
    });

    test('levenshteinDistance returns correct distance', () {
      final result = 'FAB365'.levenshteinDistance('FAB365');
      expect(result, 0);
    });

    test('levenshteinDistance returns correct distance', () {
      final result = 'Fab365_StarWars_Star-Destroyer_Bridge-A_PC-PBT GF_14m3s.gcode'.levenshteinDistance('FAB365');
      expect(result, 0);
    });
  });
}