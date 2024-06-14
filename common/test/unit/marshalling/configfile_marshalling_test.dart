/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';
import 'dart:io';

import 'package:common/data/dto/config/config_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Test ConfigFile parsing, multi extruder one one nozzle!', () {
    final configFile = File('test_resources/marshalling/multi_extruder_configfile.json');
    var configFileJson = jsonDecode(configFile.readAsStringSync());

    var config = ConfigFile.parse(configFileJson['settings']);

    expect(config, isNotNull);
  });

  test('Test ConfigFile parsing, multi extruder one one nozzle!', () {
    final configFile = File('test_resources/marshalling/multi_extruder_config_two.json');
    var configFileJson = jsonDecode(configFile.readAsStringSync());

    var config = ConfigFile.parse(configFileJson['settings']);

    expect(config, isNotNull);
  });

  test('Test user configfile!', () {
    final configFile = File('test_resources/marshalling/config_file.json');
    var configFileJson = jsonDecode(configFile.readAsStringSync());

    var config = ConfigFile.parse(configFileJson['settings']);

    expect(config, isNotNull);
  });

  test('Test Entire config file parsing', () {
    final configFile = File(
        'test_resources/marshalling/v2_1111_config.json'); // The file only contains the settings part of the config!
    var configFileJson = jsonDecode(configFile.readAsStringSync());

    var config = ConfigFile.parse(configFileJson);

    expect(config, isNotNull);
    // Verify heater_bed config
    expect(config.configHeaterBed, isNotNull);
    expect(config.configHeaterBed?.heaterPin, 'PD13');
    expect(config.configHeaterBed?.sensorType, 'NTC 100K MGB18-104F39050L32');
    expect(config.configHeaterBed?.sensorPin, 'PF3');
    expect(config.configHeaterBed?.control, 'pid');
    expect(config.configHeaterBed?.minTemp, 15);
    expect(config.configHeaterBed?.maxTemp, 120);
    expect(config.configHeaterBed?.maxPower, 0.6);

    // Verify printer config
    expect(config.configPrinter, isNotNull);
    expect(config.configPrinter?.kinematics, 'corexy');
    expect(config.configPrinter?.maxVelocity, 500);
    expect(config.configPrinter?.maxAccel, 7000);
    expect(config.configPrinter?.maxAccelToDecel, 3500);
    expect(config.configPrinter?.squareCornerVelocity, 8);

    // Verify extruder config
    expect(config.extruders, hasLength(1));
    expect(config.extruderForIndex(0), isNotNull);
    expect(config.extruderForIndex(0)?.name, 'extruder');
    expect(config.extruderForIndex(0)?.nozzleDiameter, 0.4);
    expect(config.extruderForIndex(0)?.maxExtrudeOnlyDistance, 200);
    expect(config.extruderForIndex(0)?.minTemp, 10);
    expect(config.extruderForIndex(0)?.minExtrudeTemp, 140);
    expect(config.extruderForIndex(0)?.maxTemp, 300);
    expect(config.extruderForIndex(0)?.maxPower, 1);
    expect(config.extruderForIndex(0)?.filamentDiameter, 1.75);

    // Verify outputs
    expect(config.outputs, hasLength(1));
    expect(config.outputs['beeper'], isNotNull);
    expect(config.outputs['beeper']?.name, 'beeper');
    expect(config.outputs['beeper']?.pwm, false);
    expect(config.outputs['beeper']?.scale, 1.0);

    // Verify steppers
    expect(config.steppers, hasLength(6));
    expect(config.steppers['x'], isNotNull);
    expect(config.steppers['x']?.name, 'x');
    expect(config.steppers['y'], isNotNull);
    expect(config.steppers['y']?.name, 'y');
    expect(config.steppers['z'], isNotNull);
    expect(config.steppers['z']?.name, 'z');
    expect(config.steppers['z1'], isNotNull);
    expect(config.steppers['z1']?.name, 'z1');
    expect(config.steppers['z2'], isNotNull);
    expect(config.steppers['z2']?.name, 'z2');
    expect(config.steppers['z3'], isNotNull);
    expect(config.steppers['z3']?.name, 'z3');

    // Verify GCodeMacros
    expect(config.gcodeMacros, hasLength(50));
    expect(config.gcodeMacros['cancel_print'], isNotNull);
    expect(config.gcodeMacros['bed_mesh_calibrate'], isNotNull);
    expect(config.gcodeMacros['setup_kamp_meshing'], isNotNull);
    expect(config.gcodeMacros['line_purge'], isNotNull);
    expect(config.gcodeMacros['setup_line_purge'], isNotNull);
    expect(config.gcodeMacros['mesh_config'], isNotNull);
    expect(config.gcodeMacros['voron_purge'], isNotNull);
    expect(config.gcodeMacros['setup_voron_purge'], isNotNull);
    expect(config.gcodeMacros['clean_nozzle'], isNotNull);
    expect(config.gcodeMacros['m600'], isNotNull);
    expect(config.gcodeMacros['m602'], isNotNull);
    expect(config.gcodeMacros['load_filament'], isNotNull);
    expect(config.gcodeMacros['_sb_vars'], isNotNull);
    expect(config.gcodeMacros['_set_sb_leds'], isNotNull);
    expect(config.gcodeMacros['_set_sb_leds_by_name'], isNotNull);
    expect(config.gcodeMacros['_set_logo_leds'], isNotNull);
    expect(config.gcodeMacros['_set_nozzle_leds'], isNotNull);
    expect(config.gcodeMacros['set_logo_leds_off'], isNotNull);
    expect(config.gcodeMacros['set_nozzle_leds_on'], isNotNull);
    expect(config.gcodeMacros['set_nozzle_leds_off'], isNotNull);
    expect(config.gcodeMacros['status_off'], isNotNull);
    expect(config.gcodeMacros['status_ready'], isNotNull);
    expect(config.gcodeMacros['status_busy'], isNotNull);
    expect(config.gcodeMacros['status_heating'], isNotNull);
    expect(config.gcodeMacros['status_leveling'], isNotNull);
    expect(config.gcodeMacros['status_homing'], isNotNull);
    expect(config.gcodeMacros['status_cleaning'], isNotNull);
    expect(config.gcodeMacros['status_meshing'], isNotNull);
    expect(config.gcodeMacros['status_calibrating_z'], isNotNull);
    expect(config.gcodeMacros['status_printing'], isNotNull);
    expect(config.gcodeMacros['_bedfanvars'], isNotNull);
    expect(config.gcodeMacros['bedfansslow'], isNotNull);
    expect(config.gcodeMacros['bedfansfast'], isNotNull);
    expect(config.gcodeMacros['bedfansoff'], isNotNull);
    expect(config.gcodeMacros['set_heater_temperature'], isNotNull);
    expect(config.gcodeMacros['m190'], isNotNull);
    expect(config.gcodeMacros['m140'], isNotNull);
    expect(config.gcodeMacros['turn_off_heaters'], isNotNull);
    expect(config.gcodeMacros['print_start'], isNotNull);
    expect(config.gcodeMacros['m900'], isNotNull);
    expect(config.gcodeMacros['mr_notify'], isNotNull);
    expect(config.gcodeMacros['axes_shaper_calibration'], isNotNull);
    expect(config.gcodeMacros['belts_shaper_calibration'], isNotNull);
    expect(config.gcodeMacros['vibrations_calibration'], isNotNull);
    expect(config.gcodeMacros['g32'], isNotNull);
    expect(config.gcodeMacros['l_on'], isNotNull);
    expect(config.gcodeMacros['l_off'], isNotNull);
    expect(config.gcodeMacros['print_end'], isNotNull);
    expect(config.gcodeMacros['pause'], isNotNull);
    expect(config.gcodeMacros['resume'], isNotNull);

    // Verify leds
    expect(config.leds, hasLength(4));
    expect(config.leds['sb_leds'], isNotNull);
    expect(config.leds['case_dotstars'], isNotNull);
    expect(config.leds['fysetc_mini12864'], isNotNull);
    expect(config.leds['caselight'], isNotNull);

    // Verify Print cooling fan
    expect(config.configPrintCoolingFan, isNotNull);
    expect(config.configPrintCoolingFan?.maxPower, 1);
    expect(config.configPrintCoolingFan?.kickStartTime, 0.5);
    expect(config.configPrintCoolingFan?.offBelow, 0.1);
    expect(config.configPrintCoolingFan?.cycleTime, 0.01);
    expect(config.configPrintCoolingFan?.hardwarePwm, false);
    expect(config.configPrintCoolingFan?.shutdownSpeed, 0);
    expect(config.configPrintCoolingFan?.pin, 'PA8');
    expect(config.configPrintCoolingFan?.tachometerPin, isNull);
    expect(config.configPrintCoolingFan?.tachometerPpr, 2);
    expect(config.configPrintCoolingFan?.tachometerPollInterval, 0.0015);
    expect(config.configPrintCoolingFan?.enablePin, isNull);

    // Verify fans
    expect(config.fans, hasLength(4));
    expect(config.fans['bedfans'], isNotNull);
    expect(config.fans['hotend_fan'], isNotNull);
    expect(config.fans['skirt fan'], isNotNull);
    expect(config.fans['exhaust_fan'], isNotNull);

    // Verify Heaters
    expect(config.genericHeaters, hasLength(0));

    // Verify BedScrews config
    expect(config.configBedScrews, isNotNull);
    expect(config.configBedScrews?.horizontalMoveZ, 5);
    expect(config.configBedScrews?.probeHeight, 0);
    expect(config.configBedScrews?.probeSpeed, 5);
    expect(config.configBedScrews?.speed, 50);
    expect(config.configBedScrews?.screws.length, 3);

    // Verify ScrewsTiltAdjust config
    expect(config.configScrewsTiltAdjust, isNotNull);
    expect(config.configScrewsTiltAdjust?.screwThread, 'CW-M3');
    expect(config.configScrewsTiltAdjust?.horizontalMoveZ, 10);
    expect(config.configScrewsTiltAdjust?.speed, 50);

    expect(config.configScrewsTiltAdjust?.screws.length, 4);
    expect(config.configScrewsTiltAdjust?.screws[0].name, 'front left screw');
    expect(config.configScrewsTiltAdjust?.screws[0].position, [5, 30]);
    expect(config.configScrewsTiltAdjust?.screws[1].name, 'front right screw');
    expect(config.configScrewsTiltAdjust?.screws[1].position, [155, 30]);
    expect(config.configScrewsTiltAdjust?.screws[2].name, 'rear right screw');
    expect(config.configScrewsTiltAdjust?.screws[2].position, [155, 190]);
    expect(config.configScrewsTiltAdjust?.screws[3].name, 'rear left screw');
    expect(config.configScrewsTiltAdjust?.screws[3].position, [5, 190]);
  });
}
