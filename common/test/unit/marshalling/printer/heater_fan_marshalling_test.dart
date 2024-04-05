/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/fans/heater_fan.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

void main() {
  test('HeaterFan fromJson', () {
    HeaterFan obj = HeaterFanObject();

    expect(obj, isNotNull);
    expect(obj.speed, equals(0.55));
  });
  test('HeaterFan partialUpdate - speed', () {
    HeaterFan old = HeaterFanObject();

    var updateJson = {'speed': 0.99};

    var updatedObj = HeaterFan.partialUpdate(old, updateJson);

    expect(updatedObj, isNotNull);
    expect(updatedObj.speed, equals(0.99));
  });
}

HeaterFan HeaterFanObject() {
  String input =
      '{"result": {"status": {"fan": {"speed": 0.55, "rpm": null}}, "eventtime": 3801252.15548827}}';

  var jsonRaw = objectFromHttpApiResult(input, 'fan');

  return HeaterFan.fromJson(jsonRaw, 'testFan');
}
