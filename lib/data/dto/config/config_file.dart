import 'dart:collection';
import 'dart:developer';

import 'package:mobileraker/data/dto/config/config_extruder.dart';
import 'package:mobileraker/data/dto/config/config_heater_bed.dart';
import 'package:mobileraker/data/dto/config/config_output.dart';
import 'package:mobileraker/data/dto/config/config_printer.dart';
import 'package:mobileraker/data/dto/config/config_stepper.dart';

//TODO Decide regarding null values or not!
class ConfigFile {
  ConfigPrinter? configPrinter;
  ConfigHeaterBed? configHeaterBed;
  Map<String, ConfigExtruder> extruders = {};
  Map<String, ConfigOutput> outputs = {};
  Map<String, ConfigStepper> steppers = {};

  ConfigFile();

  ConfigStepper? get stepperX => steppers['x'];

  ConfigStepper? get stepperY => steppers['y'];

  ConfigFile.parse(this.rawConfig) {
    if (rawConfig.containsKey('printer'))
      configPrinter = ConfigPrinter.parse(rawConfig['printer']);
    if (rawConfig.containsKey('heater_bed'))
      configHeaterBed = ConfigHeaterBed.parse(rawConfig['heater_bed']);

    this.rawConfig.keys.forEach((key) {
      if (key.startsWith('extruder')) {
        Map<String, dynamic> jsonChild = Map.of(rawConfig[key]);
        if (jsonChild.containsKey('shared_heater')) {
          String sharedHeater = jsonChild['shared_heater'];
          Map<String, dynamic> sharedHeaterConfig =
              Map.of(rawConfig[sharedHeater]);
          sharedHeaterConfig
              .removeWhere((key, value) => jsonChild.containsKey(key));
          jsonChild.addAll(sharedHeaterConfig);
        }
        extruders[key] = ConfigExtruder.parse(key, jsonChild);
      }

      if (key.startsWith('output')) {
        List<String> split = key.split(" ");
        String name = split.length > 1 ? split.skip(1).join(" ") : split[0];
        Map<String, dynamic> jsonChild = Map.of(rawConfig[key]);
        outputs[name] = ConfigOutput.parse(name, jsonChild);
      }

      if (key.startsWith('stepper')) {
        List<String> split = key.split("_");
        String name = split.length > 1 ? split.skip(1).join("_") : split[0];
        Map<String, dynamic> jsonChild = Map.of(rawConfig[key]);
        steppers[name] = ConfigStepper.parse(name, jsonChild);
      }
    });

    //ToDo parse the config for e.g. EXTRUDERS (Temp settings), ...
  }

  Map<String, dynamic> rawConfig = {};

  bool saveConfigPending = false;

  bool get hasQuadGantry => rawConfig.containsKey('quad_gantry_level');

  bool get hasBedMesh => rawConfig.containsKey('bed_mesh');

  ConfigExtruder? get primaryExtruder => extruders['extruder'];
}
