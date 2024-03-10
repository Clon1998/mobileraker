/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/extensions/string_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MobilerakerString', () {
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
  });
}
