/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/fans/print_fan.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

void main() {
  test('PrintFan fromJson', () {
    PrintFan obj = printFanObject();

    expect(obj, isNotNull);
    expect(obj.speed, equals(0.55));
  });
  test('PrintFan partialUpdate - speed', () {
    PrintFan old = printFanObject();

    var updateJson = {'speed': 0.99};

    var updatedObj = PrintFan.partialUpdate(old, updateJson);

    expect(updatedObj, isNotNull);
    expect(updatedObj.speed, equals(0.99));
  });
}

PrintFan printFanObject() {
  String input =
      '{"result": {"status": {"fan": {"speed": 0.55, "rpm": null}}, "eventtime": 3801252.15548827}}';

  var jsonRaw = objectFromHttpApiResult(input, 'fan');

  return PrintFan.fromJson(jsonRaw);
}
