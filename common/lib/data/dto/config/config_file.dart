/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

//TODO Decide regarding null values or not!
import 'package:common/data/dto/config/config_screws_tilt_adjust.dart';
import 'package:common/util/extensions/string_extension.dart';
import 'package:flutter/foundation.dart';

import 'config_bed_screws.dart';
import 'config_extruder.dart';
import 'config_file_object_identifiers_enum.dart';
import 'config_gcode_macro.dart';
import 'config_heater_bed.dart';
import 'config_heater_generic.dart';
import 'config_output.dart';
import 'config_printer.dart';
import 'config_stepper.dart';
import 'fan/config_controller_fan.dart';
import 'fan/config_fan.dart';
import 'fan/config_generic_fan.dart';
import 'fan/config_heater_fan.dart';
import 'fan/config_print_cooling_fan.dart';
import 'fan/config_temperature_fan.dart';
import 'led/config_dotstar.dart';
import 'led/config_dumb_led.dart';
import 'led/config_led.dart';
import 'led/config_neopixel.dart';
import 'led/config_pca_led.dart';

var stepperRegex = RegExp(r'^stepper_(\w+)$', caseSensitive: false);

class ConfigFile {
  ConfigPrinter? configPrinter;
  ConfigHeaterBed? configHeaterBed;
  ConfigPrintCoolingFan? configPrintCoolingFan;
  ConfigBedScrews? configBedScrews;
  ConfigScrewsTiltAdjust? configScrewsTiltAdjust;
  Map<String, ConfigExtruder> extruders = {};
  Map<String, ConfigOutput> outputs = {};
  Map<String, ConfigStepper> steppers = {};
  Map<String, ConfigGcodeMacro> gcodeMacros = {};
  Map<String, ConfigLed> leds = {};
  Map<String, ConfigFan> fans = {};
  Map<String, ConfigHeaterGeneric> genericHeaters = {};

  ConfigFile();

  ConfigStepper? get stepperX => steppers['x'];

  ConfigStepper? get stepperY => steppers['y'];

  ConfigFile.parse(this.rawConfig) {
    for (String key in rawConfig.keys) {
      var klipperObjectIdentifier = key.toKlipperObjectIdentifier();
      String objectIdentifier = klipperObjectIdentifier.$1;
      String objectName = klipperObjectIdentifier.$2 ?? klipperObjectIdentifier.$1;

      Map<String, dynamic> jsonChild = Map.of(rawConfig[key]);

      if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.heater_bed)) {
        configHeaterBed = ConfigHeaterBed.fromJson(rawConfig['heater_bed']);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.printer)) {
        configPrinter = ConfigPrinter.fromJson(rawConfig['printer']);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.extruder)) {
        if (jsonChild.containsKey('shared_heater')) {
          String sharedHeater = jsonChild['shared_heater'];
          Map<String, dynamic> sharedHeaterConfig = Map.of(rawConfig[sharedHeater]);
          sharedHeaterConfig.removeWhere((key, value) => jsonChild.containsKey(key));
          jsonChild.addAll(sharedHeaterConfig);
        }
        extruders[objectIdentifier] = ConfigExtruder.fromJson(objectIdentifier, jsonChild);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.output_pin)) {
        outputs[objectName] = ConfigOutput.fromJson(objectName, jsonChild);
      } else if (stepperRegex.hasMatch(key)) {
        var match = stepperRegex.firstMatch(key)!;
        steppers[match.group(1)!] = ConfigStepper.fromJson(match.group(1)!, jsonChild);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.gcode_macro)) {
        gcodeMacros[objectName] = ConfigGcodeMacro.fromJson(objectName, jsonChild);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.dotstar)) {
        leds[objectName] = ConfigDotstar.fromJson(objectName, jsonChild);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.neopixel)) {
        leds[objectName] = ConfigNeopixel.fromJson(objectName, jsonChild);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.led)) {
        leds[objectName] = ConfigDumbLed.fromJson(objectName, jsonChild);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.pca9533) ||
          objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.pca9632)) {
        //pca9533 and pcapca9632
        leds[objectName] = ConfigPcaLed.fromJson(objectName, jsonChild);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.fan)) {
        configPrintCoolingFan = ConfigPrintCoolingFan.fromJson(jsonChild);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.heater_fan)) {
        fans[objectName] = ConfigHeaterFan.fromJson(objectName, jsonChild);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.controller_fan)) {
        fans[objectName] = ConfigControllerFan.fromJson(objectName, jsonChild);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.temperature_fan)) {
        fans[objectName] = ConfigTemperatureFan.fromJson(objectName, jsonChild);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.fan_generic)) {
        fans[objectName] = ConfigGenericFan.fromJson(objectName, jsonChild);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.heater_generic)) {
        genericHeaters[objectName] = ConfigHeaterGeneric.fromJson(objectName, jsonChild);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.bed_screws)) {
        configBedScrews = ConfigBedScrews.fromJson(jsonChild);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.screws_tilt_adjust)) {
        configScrewsTiltAdjust = ConfigScrewsTiltAdjust.fromJson(jsonChild);
      }
    }

    //ToDo parse the config for e.g. EXTRUDERS (Temp settings), ...
    // TODO migrate to the entire key instead of just the objectName. The problem is LEDs, Fans of different types can have the same name!
  }

  Map<String, dynamic> rawConfig = {};

  bool saveConfigPending = false;

  bool get hasQuadGantry => rawConfig.containsKey('quad_gantry_level');

  bool get hasBedMesh => rawConfig.containsKey('bed_mesh');

  bool get hasScrewTiltAdjust => rawConfig.containsKey('screws_tilt_adjust');

  bool get hasZTilt => rawConfig.containsKey('z_tilt');

  bool get hasBedScrews => rawConfig.containsKey('bed_screws');

  /// Either has BlTouch or a normal probe!
  bool get hasProbe => rawConfig.containsKey('probe') || rawConfig.containsKey('bltouch');

  bool get hasVirtualZEndstop => steppers['z']?.endstopPin?.contains('z_virtual_endstop') == true;

  ConfigExtruder? get primaryExtruder => extruders['extruder'];

  ConfigExtruder? extruderForIndex(int idx) => extruders['extruder${idx > 0 ? idx : ''}'];

  double get maxX => stepperX?.positionMax ?? 300;

  double get minX => stepperX?.positionMin ?? 0;

  double get maxY => stepperY?.positionMax ?? 300;

  double get minY => stepperY?.positionMin ?? 0;

  double get sizeX => maxX - minX;

  double get sizeY => maxY - minY;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfigFile &&
          runtimeType == other.runtimeType &&
          configPrinter == other.configPrinter &&
          configHeaterBed == other.configHeaterBed &&
          mapEquals(extruders, other.extruders) &&
          mapEquals(outputs, other.outputs) &&
          mapEquals(steppers, other.steppers) &&
          mapEquals(gcodeMacros, other.gcodeMacros) &&
          mapEquals(leds, other.leds) &&
          mapEquals(fans, other.fans) &&
          mapEquals(genericHeaters, other.genericHeaters) &&
          rawConfig == other.rawConfig &&
          saveConfigPending == other.saveConfigPending;

  @override
  int get hashCode =>
      configPrinter.hashCode ^
      configHeaterBed.hashCode ^
      extruders.hashCode ^
      outputs.hashCode ^
      steppers.hashCode ^
      rawConfig.hashCode ^
      saveConfigPending.hashCode;

  @override
  String toString() {
    return 'ConfigFile{configPrinter: $configPrinter, configHeaterBed: $configHeaterBed, extruders: $extruders, outputs: $outputs, steppers: $steppers, rawConfig: $rawConfig, saveConfigPending: $saveConfigPending}';
  }
}
