/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/fans/controller_fan.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

void main() {
  test('ControllerFan fromJson', () {
    ControllerFan obj = ControllerFanObject();

    expect(obj, isNotNull);
    expect(obj.speed, equals(0.55));
  });
  test('ControllerFan partialUpdate - speed', () {
    ControllerFan old = ControllerFanObject();

    var updateJson = {'speed': 0.99};

    var updatedObj = ControllerFan.partialUpdate(old, updateJson);

    expect(updatedObj, isNotNull);
    expect(updatedObj.speed, equals(0.99));
  });
}

ControllerFan ControllerFanObject() {
  String input =
      '{"result": {"status": {"fan": {"speed": 0.55, "rpm": null}}, "eventtime": 3801252.15548827}}';

  var jsonRaw = objectFromHttpApiResult(input, 'fan');

  return ControllerFan.fromJson(jsonRaw, 'testFan');
}
