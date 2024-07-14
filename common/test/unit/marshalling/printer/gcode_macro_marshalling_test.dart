/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/gcode_macro.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

void main() {
  test('GcodeMacro fromJson', () {
    GcodeMacro obj = macroObject();
    expect(obj, isNotNull);
    expect(obj.name, equals('T0'));
    expect(obj.vars, {
      "active": true,
      "color": "FFFF00",
      "hotend_type": "UHF",
      "has_cht_nozzle": false,
      "cooling_position_to_nozzle_distance": 40,
      "tooolhead_sensor_to_extruder_gear_distance": 15,
      "extruder_gear_to_cooling_position_distance": 30,
      "filament_loading_nozzle_offset": -5,
      "filament_grabbing_length": 5,
      "filament_grabbing_speed": 1,
      "enable_insert_detection": true,
      "enable_runout_detection": true,
      "enable_clog_detection": true,
      "unload_after_runout": true,
      "purge_after_load": 0,
      "purge_before_unload": 0,
      "extruder_load_speed": 60,
      "filament_load_speed": 10,
      "standby": false,
      "temperature_offset": 0,
      "has_oozeguard": false,
      "has_front_arm_nozzle_wiper": true,
      "resume_after_insert": false
    });
  });
  test('GcodeMacro partialUpdate - value', () {
    GcodeMacro old = macroObject();

    var updateJson = {'value': 0.99, "resume_after_insert": true};

    var updatedObj = GcodeMacro.partialUpdate(old, updateJson);

    expect(updatedObj, isNotNull);
    expect(updatedObj.name, equals('T0'));
    expect(updatedObj.vars, {
      "active": true,
      "color": "FFFF00",
      "hotend_type": "UHF",
      "has_cht_nozzle": false,
      "cooling_position_to_nozzle_distance": 40,
      "tooolhead_sensor_to_extruder_gear_distance": 15,
      "extruder_gear_to_cooling_position_distance": 30,
      "filament_loading_nozzle_offset": -5,
      "filament_grabbing_length": 5,
      "filament_grabbing_speed": 1,
      "enable_insert_detection": true,
      "enable_runout_detection": true,
      "enable_clog_detection": true,
      "unload_after_runout": true,
      "purge_after_load": 0,
      "purge_before_unload": 0,
      "extruder_load_speed": 60,
      "filament_load_speed": 10,
      "standby": false,
      "temperature_offset": 0,
      "has_oozeguard": false,
      "has_front_arm_nozzle_wiper": true,
      "resume_after_insert": true,
      "value": 0.99,
    });
  });
}

GcodeMacro macroObject() {
  String input =
      '{"result":{"eventtime":1713688.947962376,"status":{"gcode_macro T0":{"active":true,"color":"FFFF00","hotend_type":"UHF","has_cht_nozzle":false,"cooling_position_to_nozzle_distance":40,"tooolhead_sensor_to_extruder_gear_distance":15,"extruder_gear_to_cooling_position_distance":30,"filament_loading_nozzle_offset":-5,"filament_grabbing_length":5,"filament_grabbing_speed":1,"enable_insert_detection":true,"enable_runout_detection":true,"enable_clog_detection":true,"unload_after_runout":true,"purge_after_load":0,"purge_before_unload":0,"extruder_load_speed":60,"filament_load_speed":10,"standby":false,"temperature_offset":0,"has_oozeguard":false,"has_front_arm_nozzle_wiper":true,"resume_after_insert":false}}}}';

  var jsonRaw = objectFromHttpApiResult(input, 'gcode_macro T0');

  return GcodeMacro.fromJson(jsonRaw, 'T0');
}
