/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
import 'package:common/util/extensions/string_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MobilerakerString', () {
    // Tests for toKlipperObjectIdentifier
    test('isKlipperObject returns true when object name matches', () {
      final result = 'temperature_sensor'.isKlipperObject(ConfigFileObjectIdentifiers.temperature_sensor);
      expect(result, true);
    });

    test('isKlipperObject returns false when object name does not match', () {
      final result = 'temperature_sensor'.isKlipperObject(ConfigFileObjectIdentifiers.extruder);
      expect(result, false);
    });

    test('isKlipperObject returns true when object name matches regex', () {
      var result = 'extruder1'.isKlipperObject(ConfigFileObjectIdentifiers.extruder);
      expect(result, true);
      result = 'extruder'.isKlipperObject(ConfigFileObjectIdentifiers.extruder);
      expect(result, true);
    });

    test('isKlipperObject returns false when object name does not match regex', () {
      final result = 'fam'.isKlipperObject(ConfigFileObjectIdentifiers.extruder);
      expect(result, false);
    });

    test('toKlipperObjectIdentifier returns lowercase identifier and null when single word', () {
      final result = 'Temperature'.toKlipperObjectIdentifier();
      expect(result, ('temperature', null));
    });

    test('toKlipperObjectIdentifier returns lowercase identifier and trimmed object name when multiple words', () {
      final result = 'Temperature sensor_name'.toKlipperObjectIdentifier();
      expect(result, ('temperature', 'sensor_name'));
    });

    test('toKlipperObjectIdentifier handles leading and trailing whitespaces', () {
      final result = '  Temperature sensor_name  '.toKlipperObjectIdentifier();
      expect(result, ('temperature', 'sensor_name'));
    });

    test('toKlipperObjectIdentifier handles multiple whitespaces between words', () {
      final result = 'Temperature    sensor_name'.toKlipperObjectIdentifier();
      expect(result, ('temperature', 'sensor_name'));
    });

    test('toKlipperObjectIdentifier handles multiple sections with whitespaces', () {
      final result = 'Temperature sensor_name extra_part'.toKlipperObjectIdentifier();
      expect(result, ('temperature', 'sensor_name extra_part'));
    });

    test('toKlipperObjectIdentifier handles multiple sections with multiple whitespaces', () {
      final result = 'Temperature    sensor_name    extra_part'.toKlipperObjectIdentifier();
      expect(result, ('temperature', 'sensor_name    extra_part'));
    });

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

    // Tests for isKlipperObject
    test('isKlipperObject returns true when object name matches', () {
      final result = 'temperature_sensor'.isKlipperObject(ConfigFileObjectIdentifiers.temperature_sensor);
      expect(result, true);
    });

    test('isKlipperObject returns false when object name does not match', () {
      final result = 'temperature_sensor'.isKlipperObject(ConfigFileObjectIdentifiers.extruder);
      expect(result, false);
    });

    test('isKlipperObject returns true when object name matches regex', () {
      var result = 'extruder1'.isKlipperObject(ConfigFileObjectIdentifiers.extruder);
      expect(result, true);
      result = 'extruder'.isKlipperObject(ConfigFileObjectIdentifiers.extruder);
      expect(result, true);
    });

    test('isKlipperObject returns false when object name does not match regex', () {
      final result = 'fam'.isKlipperObject(ConfigFileObjectIdentifiers.extruder);
      expect(result, false);
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