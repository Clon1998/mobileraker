/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/manual_probe.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

void main() {
  test('ManualProbe fromJson', () {
    ManualProbe obj = manualProbeObject();

    expect(obj, isNotNull);
    expect(obj.zPosition, equals(5555.271));
    expect(obj.isActive, isTrue);
    expect(obj.zPositionLower, equals(5.221));
    expect(obj.zPositionUpper, equals(5.444));
  });
  group('ManualProbe partialUpdate', () {
    test('is_active', () {
      ManualProbe old = manualProbeObject();

      var updateJson = {'is_active': false};

      var updatedObj = ManualProbe.partialUpdate(old, updateJson);
      expect(updatedObj, isNotNull);
      expect(updatedObj.zPosition, equals(5555.271));
      expect(updatedObj.isActive, isFalse);
      expect(updatedObj.zPositionLower, equals(5.221));
      expect(updatedObj.zPositionUpper, equals(5.444));
    });
    test('z_position', () {
      ManualProbe old = manualProbeObject();

      var updateJson = {'z_position': 222.4444};

      var updatedObj = ManualProbe.partialUpdate(old, updateJson);
      expect(updatedObj, isNotNull);
      expect(updatedObj.zPosition, equals(222.444));
      expect(updatedObj.isActive, isTrue);
      expect(updatedObj.zPositionLower, equals(5.221));
      expect(updatedObj.zPositionUpper, equals(5.444));
    });
    test('z_position_upper', () {
      ManualProbe old = manualProbeObject();

      var updateJson = {'z_position_upper': 123.4561};

      var updatedObj = ManualProbe.partialUpdate(old, updateJson);
      expect(updatedObj, isNotNull);
      expect(updatedObj.zPosition, equals(5555.271));
      expect(updatedObj.isActive, isTrue);
      expect(updatedObj.zPositionLower, equals(5.221));
      expect(updatedObj.zPositionUpper, equals(123.456));
    });
    test('z_position_lower', () {
      ManualProbe old = manualProbeObject();

      var updateJson = {'z_position_lower': 0.9872};

      var updatedObj = ManualProbe.partialUpdate(old, updateJson);
      expect(updatedObj, isNotNull);
      expect(updatedObj.zPosition, equals(5555.271));
      expect(updatedObj.isActive, isTrue);
      expect(updatedObj.zPositionLower, equals(0.987));
      expect(updatedObj.zPositionUpper, equals(5.444));
    });
  });
}

ManualProbe manualProbeObject() {
  String input =
      '{"result": {"status": {"manual_probe": {"z_position": 5555.271111, "is_active": true, "z_position_upper": 5.44412, "z_position_lower": 5.221249999983016}}, "eventtime": 4332661.501017012}}';

  var jsonRaw = objectFromHttpApiResult(input, 'manual_probe');

  return ManualProbe.fromJson(jsonRaw);
}
