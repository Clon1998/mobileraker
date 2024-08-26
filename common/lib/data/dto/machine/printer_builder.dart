/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/bed_mesh/bed_mesh.dart';
import 'package:common/data/dto/machine/fans/generic_fan.dart';
import 'package:common/data/dto/machine/filament_sensors/filament_motion_sensor.dart';
import 'package:common/data/dto/machine/filament_sensors/filament_sensor.dart';
import 'package:common/data/dto/machine/gcode_macro.dart';
import 'package:common/data/dto/machine/print_stats.dart';
import 'package:common/data/dto/machine/screws_tilt_adjust/screws_tilt_adjust.dart';
import 'package:common/data/dto/machine/z_thermal_adjust.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/util/extensions/string_extension.dart';
import 'package:common/util/logger.dart';

import '../config/config_file.dart';
import '../config/config_file_object_identifiers_enum.dart';
import '../files/gcode_file.dart';
import 'bed_screw.dart';
import 'display_status.dart';
import 'exclude_object.dart';
import 'fans/controller_fan.dart';
import 'fans/heater_fan.dart';
import 'fans/named_fan.dart';
import 'fans/print_fan.dart';
import 'fans/temperature_fan.dart';
import 'filament_sensors/filament_switch_sensor.dart';
import 'firmware_retraction.dart';
import 'gcode_move.dart';
import 'heaters/extruder.dart';
import 'heaters/generic_heater.dart';
import 'heaters/heater_bed.dart';
import 'leds/addressable_led.dart';
import 'leds/dumb_led.dart';
import 'leds/led.dart';
import 'manual_probe.dart';
import 'motion_report.dart';
import 'output_pin.dart';
import 'printer.dart';
import 'temperature_sensor.dart';
import 'toolhead.dart';
import 'virtual_sd_card.dart';

final Map<ConfigFileObjectIdentifiers, Function?> _subToPrinterObjects = {
  ConfigFileObjectIdentifiers.bed_mesh: PrinterBuilder._updateBedMesh,
  ConfigFileObjectIdentifiers.bed_screws: PrinterBuilder._updateBedScrew,
  ConfigFileObjectIdentifiers.configfile: PrinterBuilder._updateConfigFile,
  ConfigFileObjectIdentifiers.controller_fan: PrinterBuilder._updateControllerFan,
  ConfigFileObjectIdentifiers.display_status: PrinterBuilder._updateDisplayStatus,
  ConfigFileObjectIdentifiers.dotstar: PrinterBuilder._updateAddressableLed,
  ConfigFileObjectIdentifiers.exclude_object: PrinterBuilder._updateExcludeObject,
  ConfigFileObjectIdentifiers.extruder: PrinterBuilder._updateExtruder,
  ConfigFileObjectIdentifiers.fan: PrinterBuilder._updatePrintFan,
  ConfigFileObjectIdentifiers.fan_generic: PrinterBuilder._updateGenericFan,
  ConfigFileObjectIdentifiers.filament_motion_sensor: PrinterBuilder._updateFilamentMotionSensor,
  ConfigFileObjectIdentifiers.filament_switch_sensor: PrinterBuilder._updateFilamentSwitchSensor,
  ConfigFileObjectIdentifiers.firmware_retraction: PrinterBuilder._updateFirmwareRetraction,
  ConfigFileObjectIdentifiers.gcode_macro: PrinterBuilder._updateGcodeMacro,
  ConfigFileObjectIdentifiers.gcode_move: PrinterBuilder._updateGCodeMove,
  ConfigFileObjectIdentifiers.heater_bed: PrinterBuilder._updateHeaterBed,
  ConfigFileObjectIdentifiers.heater_fan: PrinterBuilder._updateHeaterFan,
  ConfigFileObjectIdentifiers.heater_generic: PrinterBuilder._updateGenericHeater,
  ConfigFileObjectIdentifiers.led: PrinterBuilder._updateDumbLed,
  ConfigFileObjectIdentifiers.manual_probe: PrinterBuilder._updateManualProbe,
  ConfigFileObjectIdentifiers.motion_report: PrinterBuilder._updateMotionReport,
  ConfigFileObjectIdentifiers.neopixel: PrinterBuilder._updateAddressableLed,
  ConfigFileObjectIdentifiers.output_pin: PrinterBuilder._updateOutputPin,
  ConfigFileObjectIdentifiers.pca9533: PrinterBuilder._updateDumbLed,
  ConfigFileObjectIdentifiers.pca9632: PrinterBuilder._updateDumbLed,
  ConfigFileObjectIdentifiers.print_stats: PrinterBuilder._updatePrintStat,
  ConfigFileObjectIdentifiers.screws_tilt_adjust: PrinterBuilder._updateScrewsTiltAdjust,
  ConfigFileObjectIdentifiers.temperature_fan: PrinterBuilder._updateTemperatureFan,
  ConfigFileObjectIdentifiers.temperature_sensor: PrinterBuilder._updateTemperatureSensor,
  ConfigFileObjectIdentifiers.toolhead: PrinterBuilder._updateToolhead,
  ConfigFileObjectIdentifiers.virtual_sdcard: PrinterBuilder._updateVirtualSd,
  ConfigFileObjectIdentifiers.z_thermal_adjust: PrinterBuilder._updateZThermalAdjust,
};

class PrinterBuilder {
  PrinterBuilder();

  factory PrinterBuilder.preview() {
    var toolhead = const Toolhead();
    var gCodeMove = const GCodeMove();
    var motionReport = const MotionReport();
    var print = const PrintStats();
    var configFile = ConfigFile();
    var virtualSdCard = const VirtualSdCard();

    return PrinterBuilder()
      ..toolhead = toolhead
      ..gCodeMove = gCodeMove
      ..motionReport = motionReport
      ..print = print
      ..configFile = configFile
      ..virtualSdCard = virtualSdCard;
  }

  PrinterBuilder.fromPrinter(Printer printer)
      : toolhead = printer.toolhead,
        extruders = printer.extruders,
        heaterBed = printer.heaterBed,
        printFan = printer.printFan,
        gCodeMove = printer.gCodeMove,
        print = printer.print,
        excludeObject = printer.excludeObject,
        configFile = printer.configFile,
        virtualSdCard = printer.virtualSdCard,
        manualProbe = printer.manualProbe,
        bedScrew = printer.bedScrew,
        screwsTiltAdjust = printer.screwsTiltAdjust,
        firmwareRetraction = printer.firmwareRetraction,
        bedMesh = printer.bedMesh,
        fans = printer.fans,
        temperatureSensors = printer.temperatureSensors,
        outputPins = printer.outputPins,
        queryableObjects = printer.queryableObjects,
        gcodeMacros = printer.gcodeMacros,
        motionReport = printer.motionReport,
        displayStatus = printer.displayStatus,
        leds = printer.leds,
        genericHeaters = printer.genericHeaters,
        filamentSensors = printer.filamentSensors,
        zThermalAdjust = printer.zThermalAdjust,
        currentFile = printer.currentFile;

  Toolhead? toolhead;
  List<Extruder> extruders = [];
  HeaterBed? heaterBed;
  PrintFan? printFan;
  GCodeMove? gCodeMove;
  MotionReport? motionReport;
  DisplayStatus? displayStatus;
  PrintStats? print;
  ExcludeObject? excludeObject;
  ConfigFile? configFile;
  VirtualSdCard? virtualSdCard;
  ManualProbe? manualProbe;
  BedScrew? bedScrew;
  ScrewsTiltAdjust? screwsTiltAdjust;
  GCodeFile? currentFile;
  FirmwareRetraction? firmwareRetraction;
  BedMesh? bedMesh;
  ZThermalAdjust? zThermalAdjust;
  Map<String, NamedFan> fans = {};
  Map<String, TemperatureSensor> temperatureSensors = {};
  Map<String, OutputPin> outputPins = {};
  List<String> queryableObjects = [];
  Map<String, GcodeMacro> gcodeMacros = {};
  Map<String, Led> leds = {};
  Map<String, GenericHeater> genericHeaters = {};
  Map<String, FilamentSensor> filamentSensors = {};

  Printer build() {
    if (toolhead == null) {
      throw const MobilerakerException('Missing field: toolhead');
    }

    if (gCodeMove == null) {
      throw const MobilerakerException('Missing field: gCodeMove');
    }
    if (motionReport == null) {
      throw const MobilerakerException('Missing field: motionReport');
    }
    if (print == null) {
      throw const MobilerakerException('Missing field: print');
    }
    if (configFile == null) {
      throw const MobilerakerException('Missing field: configFile');
    }
    if (virtualSdCard == null) {
      throw const MobilerakerException('Missing field: virtualSdCard');
    }

    var printer = Printer(
      toolhead: toolhead!,
      extruders: extruders,
      heaterBed: heaterBed,
      printFan: printFan,
      gCodeMove: gCodeMove!,
      motionReport: motionReport!,
      displayStatus: displayStatus,
      print: print!,
      excludeObject: excludeObject,
      configFile: configFile!,
      virtualSdCard: virtualSdCard!,
      manualProbe: manualProbe,
      bedScrew: bedScrew,
      screwsTiltAdjust: screwsTiltAdjust,
      firmwareRetraction: firmwareRetraction,
      bedMesh: bedMesh,
      currentFile: currentFile,
      fans: Map.unmodifiable(fans),
      temperatureSensors: Map.unmodifiable(temperatureSensors),
      outputPins: Map.unmodifiable(outputPins),
      queryableObjects: queryableObjects,
      gcodeMacros: gcodeMacros,
      leds: Map.unmodifiable(leds),
      genericHeaters: Map.unmodifiable(genericHeaters),
      filamentSensors: Map.unmodifiable(filamentSensors),
      zThermalAdjust: zThermalAdjust,
    );
    return printer;
  }

  /// Partially updates the printer object with the given json. IT IS EXPECTED THAT THE BUILDER IS CREATED FROM THE DTO!
  PrinterBuilder partialUpdateField(String key, Map<String, dynamic> json) {
    final (cIdentifier, objectName) = key.toKlipperObjectIdentifierNEW();

    // The config identifier is not yet supported
    if (cIdentifier == null) return this;

    final updateMethodToCall = _subToPrinterObjects[cIdentifier];
    if (updateMethodToCall == null) return this; //
    // No method to update the object -> skip
    if (objectName != null) {
      updateMethodToCall(objectName, json[key], this);
    } else if (cIdentifier == ConfigFileObjectIdentifiers.extruder) {
      // Extruder is a special case....
      updateMethodToCall(key, json[key], this);
    } else {
      updateMethodToCall(json[key], this);
    }

    return this;
  }

  ////////////////////////////////
  // CODE to update fields      //
  ////////////////////////////////

  static PrinterBuilder _updateBedMesh(Map<String, dynamic> json, PrinterBuilder builder) {
    return builder..bedMesh = BedMesh.partialUpdate(builder.bedMesh, json);
  }

  static PrinterBuilder _updateBedScrew(Map<String, dynamic> json, PrinterBuilder builder) {
    return builder..bedScrew = BedScrew.partialUpdate(builder.bedScrew, json);
  }

  static PrinterBuilder _updateConfigFile(Map<String, dynamic> json, PrinterBuilder builder) {
    var config = builder.configFile ?? ConfigFile();
    if (json.containsKey('settings')) {
      config = ConfigFile.parse(json['settings']);
    }
    if (json.containsKey('save_config_pending')) {
      config.saveConfigPending = json['save_config_pending'];
    }
    return builder..configFile = config;
  }

  static PrinterBuilder _updateControllerFan(String fanName, Map<String, dynamic> fanJson, PrinterBuilder builder) {
    final curFan = builder.fans[fanName] ?? ControllerFan(name: fanName);

    if (curFan is! ControllerFan) {
      logger.w('Fan $fanName is not a ControllerFan');
      throw MobilerakerException('Fan $fanName is not a ControllerFan. Found ${_typeOrNull(curFan)}');
    }

    return builder..fans = {...builder.fans, fanName: ControllerFan.partialUpdate(curFan, fanJson)};
  }

  static PrinterBuilder _updateDisplayStatus(Map<String, dynamic> json, PrinterBuilder builder) {
    return builder..displayStatus = DisplayStatus.partialUpdate(builder.displayStatus, json);
  }

  static PrinterBuilder _updateAddressableLed(String led, Map<String, dynamic> json, PrinterBuilder builder) {
    final curLed = builder.leds[led] ?? AddressableLed(name: led);

    if (curLed is! AddressableLed) {
      logger.w('Led $led is not an AddressableLed');
      throw MobilerakerException('Led $led is not an AddressableLed. Found ${_typeOrNull(led)}');
    }

    return builder..leds = {...builder.leds, led: AddressableLed.partialUpdate(curLed, json)};
  }

  static PrinterBuilder _updateExcludeObject(Map<String, dynamic> json, PrinterBuilder builder) {
    return builder..excludeObject = ExcludeObject.partialUpdate(builder.excludeObject, json);
  }

  static PrinterBuilder _updateExtruder(String extruder, Map<String, dynamic> json, PrinterBuilder builder) {
    final num = int.tryParse(extruder.substring(8)) ?? 0;

    List<Extruder> eList = builder.extruders.toList();
    // Takes care of the case where the extruder list is not yet initialized
    if (num >= eList.length) {
      logger.w('Extruder $num is not yet initialized. Adding ${num - eList.length + 1} extruders');
      // Adding missing extruders up to the required number
      eList.addAll(
          List.generate(num - eList.length + 1, (i) => Extruder(num: eList.length + i, lastHistory: DateTime(1990))));
    }

    final Extruder current = eList[num];
    final Extruder newExtruder = Extruder.partialUpdate(current, json);
    eList[num] = newExtruder;

    return builder..extruders = List.unmodifiable(eList);
  }

  static PrinterBuilder _updatePrintFan(Map<String, dynamic> json, PrinterBuilder builder) {
    return builder..printFan = PrintFan.partialUpdate(builder.printFan, json);
  }

  static PrinterBuilder _updateGenericFan(String fanName, Map<String, dynamic> fanJson, PrinterBuilder builder) {
    final curFan = builder.fans[fanName] ?? GenericFan(name: fanName);

    if (curFan is! GenericFan) {
      logger.w('Fan $fanName is not a GenericFan');
      throw MobilerakerException('Fan $fanName is not a GenericFan. Found ${_typeOrNull(curFan)}');
    }

    return builder..fans = {...builder.fans, fanName: GenericFan.partialUpdate(curFan, fanJson)};
  }

  static PrinterBuilder _updateFilamentMotionSensor(String sensor, Map<String, dynamic> json, PrinterBuilder builder) {
    final filamentSensor = builder.filamentSensors[sensor] ?? FilamentMotionSensor(name: sensor);

    if (filamentSensor is! FilamentMotionSensor) {
      logger.w('Sensor $sensor is not a FilamentMotionSensor');
      throw MobilerakerException('Sensor $sensor is not a FilamentMotionSensor. Found ${_typeOrNull(sensor)}');
    }

    return builder
      ..filamentSensors = {
        ...builder.filamentSensors,
        sensor: FilamentMotionSensor.partialUpdate(filamentSensor, json)
      };
  }

  static PrinterBuilder _updateFilamentSwitchSensor(String sensor, Map<String, dynamic> json, PrinterBuilder builder) {
    final filamentSensor = builder.filamentSensors[sensor] ?? FilamentSwitchSensor(name: sensor);
    if (filamentSensor is! FilamentSwitchSensor) {
      logger.w('Sensor $sensor is not a FilamentSwitchSensor');
      throw MobilerakerException('Sensor $sensor is not a FilamentSwitchSensor. Found ${_typeOrNull(sensor)}');
    }

    return builder
      ..filamentSensors = {
        ...builder.filamentSensors,
        sensor: FilamentSwitchSensor.partialUpdate(filamentSensor, json)
      };
  }

  static PrinterBuilder _updateFirmwareRetraction(Map<String, dynamic> json, PrinterBuilder builder) {
    return builder..firmwareRetraction = FirmwareRetraction.partialUpdate(builder.firmwareRetraction, json);
  }

  static PrinterBuilder _updateGcodeMacro(String macro, Map<String, dynamic> json, PrinterBuilder builder) {
    final gcodeMacro = builder.gcodeMacros[macro] ?? GcodeMacro(name: macro);
    return builder..gcodeMacros = {...builder.gcodeMacros, macro: GcodeMacro.partialUpdate(gcodeMacro, json)};
  }

  static PrinterBuilder _updateGCodeMove(Map<String, dynamic> json, PrinterBuilder builder) {
    return builder..gCodeMove = GCodeMove.partialUpdate(builder.gCodeMove, json);
  }

  static PrinterBuilder _updateHeaterBed(Map<String, dynamic> json, PrinterBuilder builder) {
    return builder..heaterBed = HeaterBed.partialUpdate(builder.heaterBed, json);
  }

  static PrinterBuilder _updateHeaterFan(String fanName, Map<String, dynamic> fanJson, PrinterBuilder builder) {
    final curFan = builder.fans[fanName] ?? HeaterFan(name: fanName);

    if (curFan is! HeaterFan) {
      logger.w('Fan $fanName is not a HeaterFan');
      throw MobilerakerException('Fan $fanName is not a HeaterFan. Found ${_typeOrNull(curFan)}');
    }

    return builder..fans = {...builder.fans, fanName: HeaterFan.partialUpdate(curFan, fanJson)};
  }

  static PrinterBuilder _updateGenericHeater(String heater, Map<String, dynamic> json, PrinterBuilder builder) {
    final genericHeater = builder.genericHeaters[heater] ?? GenericHeater(name: heater, lastHistory: DateTime(1990));
    return builder
      ..genericHeaters = {...builder.genericHeaters, heater: GenericHeater.partialUpdate(genericHeater, json)};
  }

  static PrinterBuilder _updateDumbLed(String led, Map<String, dynamic> json, PrinterBuilder builder) {
    final curLed = builder.leds[led] ?? DumbLed(name: led);

    if (curLed is! DumbLed) {
      logger.w('Led $led is not an DumbLed');
      throw MobilerakerException('Led $led is not an DumbLed. Found ${_typeOrNull(led)}');
    }

    return builder..leds = {...builder.leds, led: DumbLed.partialUpdate(curLed, json)};
  }

  static PrinterBuilder _updateManualProbe(Map<String, dynamic> json, PrinterBuilder builder) {
    return builder..manualProbe = ManualProbe.partialUpdate(builder.manualProbe, json);
  }

  static PrinterBuilder _updateMotionReport(Map<String, dynamic> json, PrinterBuilder builder) {
    return builder..motionReport = MotionReport.partialUpdate(builder.motionReport, json);
  }

  static PrinterBuilder _updateOutputPin(String pin, Map<String, dynamic> json, PrinterBuilder builder) {
    final outputPin = builder.outputPins[pin] ?? OutputPin(name: pin);
    return builder..outputPins = {...builder.outputPins, pin: OutputPin.partialUpdate(outputPin, json)};
  }

  static PrinterBuilder _updatePrintStat(Map<String, dynamic> json, PrinterBuilder builder) {
    return builder..print = PrintStats.partialUpdate(builder.print, json);
  }

  static PrinterBuilder _updateScrewsTiltAdjust(Map<String, dynamic> json, PrinterBuilder builder) {
    return builder..screwsTiltAdjust = ScrewsTiltAdjust.partialUpdate(builder.screwsTiltAdjust, json);
  }

  static PrinterBuilder _updateTemperatureFan(String fanName, Map<String, dynamic> fanJson, PrinterBuilder builder) {
    final curFan = builder.fans[fanName] ?? TemperatureFan(name: fanName, lastHistory: DateTime(1990));

    if (curFan is! TemperatureFan) {
      logger.w('Fan $fanName is not a TemperatureFan');
      throw MobilerakerException('Fan $fanName is not a TemperatureFan. Found ${_typeOrNull(curFan)}');
    }

    return builder..fans = {...builder.fans, fanName: TemperatureFan.partialUpdate(curFan, fanJson)};
  }

  static PrinterBuilder _updateTemperatureSensor(String sensor, Map<String, dynamic> json, PrinterBuilder builder) {
    final temperatureSensor =
        builder.temperatureSensors[sensor] ?? TemperatureSensor(name: sensor, lastHistory: DateTime(1990));
    return builder
      ..temperatureSensors = {
        ...builder.temperatureSensors,
        sensor: TemperatureSensor.partialUpdate(temperatureSensor, json),
      };
  }

  static PrinterBuilder _updateToolhead(Map<String, dynamic> json, PrinterBuilder builder) {
    return builder..toolhead = Toolhead.partialUpdate(builder.toolhead, json);
  }

  static PrinterBuilder _updateVirtualSd(Map<String, dynamic> json, PrinterBuilder builder) {
    return builder..virtualSdCard = VirtualSdCard.partialUpdate(builder.virtualSdCard, json);
  }

  static PrinterBuilder _updateZThermalAdjust(Map<String, dynamic> json, PrinterBuilder builder) {
    final zThermalAdjust = builder.zThermalAdjust ?? ZThermalAdjust(lastHistory: DateTime(1990));
    return builder..zThermalAdjust = ZThermalAdjust.partialUpdate(zThermalAdjust, json);
  }

////////////////////////////////
// END CODE to update fields  //
////////////////////////////////
}

String _typeOrNull(dynamic obj) => obj == null ? 'null' : obj.runtimeType.toString();