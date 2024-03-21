/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/fans/generic_fan.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

void main() {
  test('GenericFan fromJson', () {
    GenericFan obj = GenericFanObject();

    expect(obj, isNotNull);
    expect(obj.speed, equals(0.55));
  });
  test('GenericFan partialUpdate - speed', () {
    GenericFan old = GenericFanObject();

    var updateJson = {'speed': 0.99};

    var updatedObj = GenericFan.partialUpdate(old, updateJson);

    expect(updatedObj, isNotNull);
    expect(updatedObj.speed, equals(0.99));
  });
}

GenericFan GenericFanObject() {
  String input =
      '{"result": {"status": {"fan": {"speed": 0.55, "rpm": null}}, "eventtime": 3801252.15548827}}';

  var jsonRaw = objectFromHttpApiResult(input, 'fan');

  return GenericFan.fromJson(jsonRaw, 'testFan');
}
