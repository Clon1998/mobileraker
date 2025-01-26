/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
import 'package:common/util/extensions/string_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MobilerakerString', () {
    // Tests for toKlipperObjectIdentifier
    test('toKlipperObjectIdentifier returns ConfigFileObjectIdentifiers and null when single word', () {
      final result = 'Temperature_Sensor'.toKlipperObjectIdentifier();
      expect(result, (ConfigFileObjectIdentifiers.temperature_sensor, null));
    });

    test('toKlipperObjectIdentifier returns ConfigFileObjectIdentifiers and trimmed object name when multiple words',
        () {
      final result = 'Temperature_Sensor sensor_name'.toKlipperObjectIdentifier();
      expect(result, (ConfigFileObjectIdentifiers.temperature_sensor, 'sensor_name'));
    });

    test('toKlipperObjectIdentifier handles leading and trailing whitespaces', () {
      final result = '  Temperature_Sensor sensor_name  '.toKlipperObjectIdentifier();
      expect(result, (ConfigFileObjectIdentifiers.temperature_sensor, 'sensor_name'));
    });

    test('toKlipperObjectIdentifier handles multiple whitespaces between words', () {
      final result = 'Temperature_Sensor    sensor_name'.toKlipperObjectIdentifier();
      expect(result, (ConfigFileObjectIdentifiers.temperature_sensor, 'sensor_name'));
    });

    test('toKlipperObjectIdentifier handles multiple sections with whitespaces', () {
      final result = 'Temperature_Sensor sensor_name extra_part'.toKlipperObjectIdentifier();
      expect(result, (ConfigFileObjectIdentifiers.temperature_sensor, 'sensor_name extra_part'));
    });

    test('toKlipperObjectIdentifier handles multiple sections with multiple whitespaces', () {
      final result = 'Temperature_Sensor    sensor_name    extra_part'.toKlipperObjectIdentifier();
      expect(result, (ConfigFileObjectIdentifiers.temperature_sensor, 'sensor_name    extra_part'));
    });

    test('toKlipperObjectIdentifier returns (null, null) when identifier is not recognized', () {
      final result = 'Unknown_Identifier'.toKlipperObjectIdentifier();
      expect(result, (null, null));
    });

    test('toKlipperObjectIdentifier handles identifiers that use regex', () {
      var result = 'extruder1'.toKlipperObjectIdentifier();
      expect(result, (ConfigFileObjectIdentifiers.extruder, null));
      result = 'extruder'.toKlipperObjectIdentifier();
      expect(result, (ConfigFileObjectIdentifiers.extruder, null));
    });

    test('levenshteinDistance returns correct distance', () {
      final result = 'FAB365'.levenshteinDistance('FAB365');
      expect(result, 0);
    });

    test('levenshteinDistance returns correct distance', () {
      final result = 'Fab365_StarWars_Star-Destroyer_Bridge-A_PC-PBT GF_14m3s.gcode'.levenshteinDistance('FAB365');
      expect(result, 57);
    });
  });
}