/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/filament_sensors/filament_motion_sensor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

void main() {
  test('FilamentMotionSensor fromJson', () {
    FilamentMotionSensor obj = fromRequest();

    expect(obj, isNotNull);
    expect(obj.name, 'motion Sensor');
    expect(obj.enabled, false);
    expect(obj.filamentDetected, true);
  });

  test('FilamentMotionSensor partialUpdate - value', () {
    FilamentMotionSensor old = fromRequest();

    var updateJson = {'enabled': true, 'filament_detected': false};

    var updatedObj = FilamentMotionSensor.partialUpdate(old, updateJson);

    expect(updatedObj, isNotNull);
    expect(updatedObj.name, 'motion Sensor');
    expect(updatedObj.enabled, true);
    expect(updatedObj.filamentDetected, false);
  });
}

FilamentMotionSensor fromRequest() {
  String input = '''
{
  "result": {
    "eventtime": 1164937.456435166,
    "status": {
      "filament_motion_sensor motion Sensor": {
        "filament_detected": true,
        "enabled": false
      }
    }
  }
}
      ''';

  var jsonRaw = objectFromHttpApiResult(input, 'filament_motion_sensor motion Sensor');

  return FilamentMotionSensor.fromJson(jsonRaw, 'motion Sensor');
}
