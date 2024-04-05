/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/output_pin.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

void main() {
  test('OutputPin fromJson', () {
    OutputPin obj = outputPinObject();

    expect(obj, isNotNull);
    expect(obj.name, equals('TEST'));
    expect(obj.value, equals(0));
  });
  test('OutputPin partialUpdate - value', () {
    OutputPin old = outputPinObject();

    var updateJson = {'value': 0.99};

    var updatedObj = OutputPin.partialUpdate(old, updateJson);

    expect(updatedObj, isNotNull);
    expect(updatedObj.name, equals('TEST'));
    expect(updatedObj.value, equals(0.99));
  });
}

OutputPin outputPinObject() {
  String input =
      '{"result": {"status": {"output_pin beeper": {"value": 0.0}}, "eventtime": 4231669.605721319}}';

  var jsonRaw = objectFromHttpApiResult(input, 'output_pin beeper');

  return OutputPin.fromJson(jsonRaw, 'TEST');
}
