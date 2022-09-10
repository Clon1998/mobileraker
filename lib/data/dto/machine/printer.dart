import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/exceptions.dart';

import '../config/config_file.dart';
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
        gcodeMacros = printer.gcodeMacros;

  Toolhead? toolhead;
  List<Extruder> extruders = [];
  HeaterBed? heaterBed;
  PrintFan? printFan;
  GCodeMove? gCodeMove;
  PrintStats? print;
  ExcludeObject? excludeObject;
  ConfigFile? configFile;
  VirtualSdCard? virtualSdCard;
  List<NamedFan> fans = [];
  List<TemperatureSensor> temperatureSensors = [];
  List<OutputPin> outputPins = [];
  List<String> queryableObjects = [];
  List<String> gcodeMacros = [];

  Printer build() {
    if (toolhead == null ||
        heaterBed == null ||
        printFan == null ||
        gCodeMove == null ||
        print == null ||
        configFile == null ||
        virtualSdCard == null) {
      throw const MobilerakerException('Missing field');
    }
    var printer = Printer(
        toolhead: toolhead!,
        extruders: extruders,
        heaterBed: heaterBed!,
        printFan: printFan!,
        gCodeMove: gCodeMove!,
        print: print!,
        excludeObject: excludeObject,
        configFile: configFile!,
        virtualSdCard: virtualSdCard!,
        fans: fans,
        temperatureSensors: temperatureSensors,
        outputPins: outputPins,
        queryableObjects: queryableObjects,
        gcodeMacros: gcodeMacros);
    return printer;
  }
}

@freezed
class Printer with _$Printer {
  const Printer._();

  const factory Printer({
    required Toolhead toolhead,
    required List<Extruder> extruders,
    required HeaterBed heaterBed,
    required PrintFan printFan,
    required GCodeMove gCodeMove,
    required PrintStats print,
    ExcludeObject? excludeObject,
    required ConfigFile configFile,
    required VirtualSdCard virtualSdCard,
    @Default([]) List<NamedFan> fans,
    @Default([]) List<TemperatureSensor> temperatureSensors,
    @Default([]) List<OutputPin> outputPins,
    @Default([]) List<String> queryableObjects,
    @Default([]) List<String> gcodeMacros,
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
