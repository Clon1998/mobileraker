/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/bed_mesh/bed_mesh.dart';
import 'package:common/data/dto/machine/filament_sensors/filament_sensor.dart';
import 'package:common/data/dto/machine/print_stats.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../config/config_file.dart';
import '../files/gcode_file.dart';
import 'bed_screw.dart';
import 'display_status.dart';
import 'exclude_object.dart';
import 'fans/named_fan.dart';
import 'fans/print_fan.dart';
import 'firmware_retraction.dart';
import 'gcode_move.dart';
import 'heaters/extruder.dart';
import 'heaters/generic_heater.dart';
import 'heaters/heater_bed.dart';
import 'leds/led.dart';
import 'manual_probe.dart';
import 'motion_report.dart';
import 'output_pin.dart';
import 'temperature_sensor.dart';
import 'toolhead.dart';
import 'virtual_sd_card.dart';

part 'printer.freezed.dart';

class PrinterBuilder {
  PrinterBuilder();

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
  GCodeFile? currentFile;
  FirmwareRetraction? firmwareRetraction;
  BedMesh? bedMesh;
  Map<String, NamedFan> fans = {};
  Map<String, TemperatureSensor> temperatureSensors = {};
  Map<String, OutputPin> outputPins = {};
  List<String> queryableObjects = [];
  List<String> gcodeMacros = [];
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
    );
    return printer;
  }
}

@freezed
class Printer with _$Printer {
  const Printer._();

  const factory Printer({
    required Toolhead toolhead,
    required List<Extruder> extruders,
    required HeaterBed? heaterBed,
    required PrintFan? printFan,
    required GCodeMove gCodeMove,
    required MotionReport motionReport,
    DisplayStatus? displayStatus,
    required PrintStats print,
    ExcludeObject? excludeObject,
    required ConfigFile configFile,
    required VirtualSdCard virtualSdCard,
    ManualProbe? manualProbe,
    BedScrew? bedScrew,
    FirmwareRetraction? firmwareRetraction,
    BedMesh? bedMesh,
    GCodeFile? currentFile,
    @Default({}) Map<String, NamedFan> fans,
    @Default({}) Map<String, TemperatureSensor> temperatureSensors,
    @Default({}) Map<String, OutputPin> outputPins,
    @Default([]) List<String> queryableObjects,
    @Default([]) List<String> gcodeMacros,
    @Default({}) Map<String, Led> leds,
    @Default({}) Map<String, GenericHeater> genericHeaters,
    @Default({}) Map<String, FilamentSensor> filamentSensors,
  }) = _Printer;

  Extruder get extruder => extruders[0]; // Fast way for first extruder -> always present!

  int get extruderCount => extruders.length;

  double get zOffset => gCodeMove.homingOrigin[2];

  DateTime? get eta {
    final remaining = remainingTimeAvg ?? 0;
    if (remaining <= 0) return null;
    return DateTime.now().add(Duration(seconds: remaining));
  }

  int? get remainingTimeByFile {
    final printDuration = this.print.printDuration;
    if (printDuration <= 0 || printProgress <= 0) return null;
    return (printDuration / printProgress - printDuration).toInt();
  }

  int? get remainingTimeByFilament {
    final printDuration = this.print.printDuration;
    final filamentUsed = this.print.filamentUsed;
    final filamentTotal = currentFile?.filamentTotal;
    if (printDuration <= 0 || filamentTotal == null || filamentTotal <= filamentUsed) return null;

    return (printDuration / (filamentUsed / filamentTotal) - printDuration).toInt();
  }

  int? get remainingTimeBySlicer {
    final printDuration = this.print.printDuration;
    final slicerEstimate = currentFile?.estimatedTime;
    if (slicerEstimate == null || printDuration <= 0 || slicerEstimate <= 0) return null;

    return (slicerEstimate - printDuration).toInt();
  }

  int? get remainingTimeAvg {
    var remaining = 0;
    var cnt = 0;

    final rFile = remainingTimeByFile ?? 0;
    if (rFile > 0) {
      remaining += rFile;
      cnt++;
    }

    final rFilament = remainingTimeByFilament ?? 0;
    if (rFilament > 0) {
      remaining += rFilament;
      cnt++;
    }

    final rSlicer = remainingTimeBySlicer ?? 0;
    if (rSlicer > 0) {
      remaining += rSlicer;
      cnt++;
    }
    if (cnt == 0) return null;

    return remaining ~/ cnt;
  }

  // Relative file position progress (0-1)
  double get printProgress {
    if (currentFile?.gcodeStartByte != null &&
        currentFile?.gcodeEndByte != null &&
        currentFile?.name == this.print.filename) {
      final gcodeStartByte = currentFile!.gcodeStartByte!;
      final gcodeEndByte = currentFile!.gcodeEndByte!;
      if (virtualSdCard.filePosition <= gcodeStartByte) return 0;
      if (virtualSdCard.filePosition >= gcodeEndByte) return 1;

      final currentPosition = virtualSdCard.filePosition - gcodeStartByte;
      final maxPosition = gcodeEndByte - gcodeStartByte;
      if (currentPosition > 0 && maxPosition > 0) {
        return currentPosition / maxPosition;
      }
    }

    return virtualSdCard.progress;
  }

  bool get isPrintFanAvailable => printFan != null;
}
