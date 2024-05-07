/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/z_thermal_adjust.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

var NOW = DateTime.now();

void main() {
  test('ZThermalAdjust fromJson', () {
    ZThermalAdjust obj = zThermalAdjust();

    expect(obj, isNotNull);
    expect(obj.enabled, true);
    expect(obj.measuredMinTemp, equals(21.2));
    expect(obj.measuredMaxTemp, equals(44.95));
    expect(obj.currentZAdjust, equals(1.23));
    expect(obj.zAdjustRefTemperature, equals(30.2));
    expect(obj.temperature, equals(24.22));
    expect(obj.lastHistory, equals(NOW));
  });
}

ZThermalAdjust zThermalAdjust() {
  String input =
      '{"result": {"status": {"z_thermal_adjust": {"enabled": true, "measured_min_temp": 21.2, "temperature":24.22, "measured_max_temp": 44.95, "current_z_adjust": 1.23, "z_adjust_ref_temperature": 30.2}}, "eventtime": 3801252.15548827}}';

  var jsonRaw = objectFromHttpApiResult(input, 'z_thermal_adjust');

  return ZThermalAdjust.fromJson({...jsonRaw, 'last_history': NOW.toIso8601String()});
}
