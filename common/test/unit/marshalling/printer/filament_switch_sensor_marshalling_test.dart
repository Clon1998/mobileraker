/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/filament_sensors/filament_switch_sensor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

void main() {
  test('FilamentSwitchSensor fromJson', () {
    FilamentSwitchSensor obj = fromRequest();

    expect(obj, isNotNull);
    expect(obj.name, 'filament_sensor');
    expect(obj.enabled, false);
    expect(obj.filamentDetected, true);
  });

  test('FilamentSwitchSensor partialUpdate - value', () {
    FilamentSwitchSensor old = fromRequest();

    var updateJson = {'enabled': true, 'filament_detected': false};

    var updatedObj = FilamentSwitchSensor.partialUpdate(old, updateJson);

    expect(updatedObj, isNotNull);
    expect(updatedObj.name, 'filament_sensor');
    expect(updatedObj.enabled, true);
    expect(updatedObj.filamentDetected, false);
  });
}

FilamentSwitchSensor fromRequest() {
  String input = '''
{
  "result": {
    "eventtime": 1164937.456435166,
    "status": {
      "filament_switch_sensor filament_sensor": {
        "filament_detected": true,
        "enabled": false
      }
    }
  }
}
      ''';

  var jsonRaw = objectFromHttpApiResult(input, 'filament_switch_sensor filament_sensor');

  return FilamentSwitchSensor.fromJson(jsonRaw, 'filament_sensor');
}
