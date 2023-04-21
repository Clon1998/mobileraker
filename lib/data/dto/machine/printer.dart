import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/data/dto/config/config_file.dart';
import 'package:mobileraker/data/dto/machine/display_status.dart';
import 'package:mobileraker/data/dto/machine/leds/led.dart';
import 'package:mobileraker/data/dto/machine/motion_report.dart';
import 'package:mobileraker/exceptions.dart';

import 'exclude_object.dart';
import 'extruder.dart';
import 'fans/named_fan.dart';
import 'fans/print_fan.dart';
import 'gcode_move.dart';
import 'heater_bed.dart';
import 'output_pin.dart';
import 'print_stats.dart';
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
        fans = printer.fans,
        temperatureSensors = printer.temperatureSensors,
        outputPins = printer.outputPins,
        queryableObjects = printer.queryableObjects,
        gcodeMacros = printer.gcodeMacros,
        motionReport = printer.motionReport,
        displayStatus = printer.displayStatus,
        leds = printer.leds;

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
  Map<String, NamedFan> fans = {};
  Map<String, TemperatureSensor> temperatureSensors = {};
  Map<String, OutputPin> outputPins = {};
  List<String> queryableObjects = [];
  List<String> gcodeMacros = [];
  Map<String, Led> leds = {};

  Printer build() {
    if (toolhead == null) {
      throw const MobilerakerException('Missing field: toolhead');
    }
    if (printFan == null) {
      throw const MobilerakerException('Missing field: printFan');
    }
    if (gCodeMove == null) {
      throw const MobilerakerException('Missing field: gCodeMove');
    }
    if (motionReport == null) {
      throw const MobilerakerException('Missing field: motionReport');
    }
    if (displayStatus == null) {
      throw const MobilerakerException('Missing field: displayStatus');
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
        printFan: printFan!,
        gCodeMove: gCodeMove!,
        motionReport: motionReport!,
        displayStatus: displayStatus!,
        print: print!,
        excludeObject: excludeObject,
        configFile: configFile!,
        virtualSdCard: virtualSdCard!,
        fans: Map.unmodifiable(fans),
        temperatureSensors: Map.unmodifiable(temperatureSensors),
        outputPins: Map.unmodifiable(outputPins),
        queryableObjects: queryableObjects,
        gcodeMacros: gcodeMacros,
        leds: Map.unmodifiable(leds));
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
    required PrintFan printFan,
    required GCodeMove gCodeMove,
    required MotionReport motionReport,
    required DisplayStatus displayStatus,
    required PrintStats print,
    ExcludeObject? excludeObject,
    required ConfigFile configFile,
    required VirtualSdCard virtualSdCard,
    @Default({}) Map<String, NamedFan> fans,
    @Default({}) Map<String, TemperatureSensor> temperatureSensors,
    @Default({}) Map<String, OutputPin> outputPins,
    @Default([]) List<String> queryableObjects,
    @Default([]) List<String> gcodeMacros,
    @Default({}) Map<String, Led> leds,
  }) = _Printer;

  Extruder get extruder =>
      extruders[0]; // Fast way for first extruder -> always present!

  int get extruderCount => extruders.length;

  double get zOffset => gCodeMove.homingOrigin[2];

  DateTime? get eta {
    if ((this.print.printDuration) > 0 && (virtualSdCard.progress) > 0) {
      var est = this.print.printDuration / virtualSdCard.progress -
          this.print.printDuration;
      return DateTime.now().add(Duration(seconds: est.round()));
    }
    return null;
  }
}
