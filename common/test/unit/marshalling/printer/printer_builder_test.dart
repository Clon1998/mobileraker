/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/printer_builder.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

var NOW = DateTime.now();

void main() {
  group('PrinterBuilder Tests', () {
    late PrinterBuilder builder;

    setUpAll(() => setupTestLogger());

    setUp(() {
      builder = PrinterBuilder.preview();
    });

    test('PrinterBuilder.preview initializes all fields correctly', () {
      expect(builder.toolhead, isNotNull);
      expect(builder.gCodeMove, isNotNull);
      expect(builder.motionReport, isNotNull);
      expect(builder.print, isNotNull);
      expect(builder.configFile, isNotNull);
      expect(builder.virtualSdCard, isNotNull);
    });

    test('Build with missing required fields should throw exception', () {
      builder.toolhead = null;
      expect(() => builder.build(), throwsA(isA<MobilerakerException>()));
    });

    test('Build method creates Printer with all required fields present', () {
      final builder = PrinterBuilder.preview();
      final printer = builder.build();

      expect(printer.toolhead, isNotNull);
      expect(printer.gCodeMove, isNotNull);
      expect(printer.motionReport, isNotNull);
      expect(printer.print, isNotNull);
      expect(printer.configFile, isNotNull);
      expect(printer.virtualSdCard, isNotNull);
    });

    test('PrinterBuilder initializes extruders, heaterBed, and fans correctly', () {
      final builder = PrinterBuilder.preview();

      expect(builder.extruders, isNotNull);
      expect(builder.fans, isNotNull);
    });

    test('PrinterBuilder initializes LEDs, genericHeaters, and filamentSensors correctly', () {
      final builder = PrinterBuilder.preview();

      expect(builder.leds, isNotNull);
      expect(builder.genericHeaters, isNotNull);
      expect(builder.filamentSensors, isNotNull);
    });

    test('Build method throws when toolhead is missing', () {
      final builder = PrinterBuilder.preview()..toolhead = null;
      expect(() => builder.build(), throwsA(isA<MobilerakerException>()));
    });

    test('Build method throws when gCodeMove is missing', () {
      final builder = PrinterBuilder.preview()..gCodeMove = null;
      expect(() => builder.build(), throwsA(isA<MobilerakerException>()));
    });

    test('Build method throws when motionReport is missing', () {
      final builder = PrinterBuilder.preview()..motionReport = null;
      expect(() => builder.build(), throwsA(isA<MobilerakerException>()));
    });

    test('Build method throws when print is missing', () {
      final builder = PrinterBuilder.preview()..print = null;
      expect(() => builder.build(), throwsA(isA<MobilerakerException>()));
    });

    test('Build method throws when configFile is missing', () {
      final builder = PrinterBuilder.preview()..configFile = null;
      expect(() => builder.build(), throwsA(isA<MobilerakerException>()));
    });

    test('Build method throws when virtualSdCard is missing', () {
      final builder = PrinterBuilder.preview()..virtualSdCard = null;
      expect(() => builder.build(), throwsA(isA<MobilerakerException>()));
    });

    test('Update Extruder with valid JSON', () {
      var json = {
        "extruder0": {"temperature": 200, "pressure_advance": 0.1}
      };
      builder.partialUpdateField('extruder0', json);
      expect(builder.extruders.length, 1);
      expect(builder.extruders[0].temperature, 200);
      expect(builder.extruders[0].pressureAdvance, 0.1);
    });

    test('Update Extruder with missing fields in JSON', () {
      var json = {
        "extruder0": {"temperature": 210}
      };
      builder.partialUpdateField('extruder0', json);
      expect(builder.extruders.length, 1);
      expect(builder.extruders[0].temperature, 210);
    });

    test('Update Extruder list with two new ones', () {
      var json = {
        "extruder1": {"temperature": 220},
        "extruder3": {"temperature": 230},
      };
      builder.partialUpdateField('extruder1', json);
      expect(builder.extruders.length, 2);
      // Default temperature is 0
      expect(builder.extruders[0].temperature, 0);
      expect(builder.extruders[1].temperature, 220);
      builder.partialUpdateField('extruder3', json);
      expect(builder.extruders.length, 4);
      // Default temperature is 0
      expect(builder.extruders[2].temperature, 0);
      expect(builder.extruders[3].temperature, 230);

      // Update extruder 1-3 again to see if they are updated correctly
      json = {
        "extruder1": {"temperature": 221},
        "extruder2": {"temperature": 244},
        "extruder3": {"temperature": 231},
      };
      builder.partialUpdateField('extruder1', json);
      builder.partialUpdateField('extruder2', json);
      builder.partialUpdateField('extruder3', json);
      expect(builder.extruders.length, 4);
      expect(builder.extruders[0].temperature, 0);
      expect(builder.extruders[1].temperature, 221);
      expect(builder.extruders[2].temperature, 244);
      expect(builder.extruders[3].temperature, 231);
    });

    test('Update with unsupported ConfigFileObjectIdentifiers should do nothing', () {
      var json = {
        "unsupported_object": {"some_field": "some_value"}
      };
      builder.partialUpdateField('unsupported_object', json);
      // No change expected
      expect(builder.queryableObjects, isEmpty);
    });

    test('Update BedMesh with valid JSON', () {
      var json = {
        'bed_mesh': {
          "mesh_min": [0, 0],
          "mesh_max": [200, 200],
        }
      };
      builder.partialUpdateField('bed_mesh', json);
      expect(builder.bedMesh, isNotNull);
      expect(builder.bedMesh!.meshMin, (0, 0));
      expect(builder.bedMesh!.meshMax, (200, 200));
    });

    test('Update extruder with higher index than current length', () {
      final builder = PrinterBuilder.preview();
      final json = {
        'extruder10': {'someField': 'someValue'}
      };
      final updatedBuilder = builder.partialUpdateField('extruder10', json);

      expect(updatedBuilder.extruders.length, greaterThanOrEqualTo(11));
      // Add more assertions based on the expected changes in extruders
    });

    test('Update extruder with negative index handles invalid indices correctly', () {
      final builder = PrinterBuilder.preview();
      final json = {
        'extruder-1': {'someField': 'someValue'}
      };
      final updatedBuilder = builder.partialUpdateField('extruder-1', json);
      expect(updatedBuilder.extruders.length, 0);
    });
  });
}
