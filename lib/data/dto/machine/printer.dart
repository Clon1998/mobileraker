import 'package:flutter/foundation.dart';
import 'package:mobileraker/data/dto/config/config_file.dart';
import 'package:mobileraker/data/dto/machine/exclude_object.dart';
import 'package:mobileraker/data/dto/machine/extruder.dart';
import 'package:mobileraker/data/dto/machine/fans/named_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/print_fan.dart';
import 'package:mobileraker/data/dto/machine/gcode_move.dart';
import 'package:mobileraker/data/dto/machine/heater_bed.dart';
import 'package:mobileraker/data/dto/machine/output_pin.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/dto/machine/temperature_sensor.dart';
import 'package:mobileraker/data/dto/machine/toolhead.dart';
import 'package:mobileraker/data/dto/machine/virtual_sd_card.dart';
import 'package:mobileraker/util/extensions/iterable_extension.dart';

class Printer {
  Toolhead toolhead = Toolhead();
  List<Extruder?> extruders = [Extruder(0)];// 1 exgruder always present!
  HeaterBed heaterBed = HeaterBed();
  PrintFan printFan = PrintFan();
  GCodeMove gCodeMove = GCodeMove();
  PrintStats print = PrintStats();

  ExcludeObject excludeObject = ExcludeObject();

  ConfigFile configFile = ConfigFile();

  Set<NamedFan> fans = {};

  Set<TemperatureSensor> temperatureSensors = {};
  Set<OutputPin> outputPins = {};

  VirtualSdCard virtualSdCard = VirtualSdCard();

  List<String> queryableObjects = [];
  List<String> gcodeMacros = [];

  Extruder get extruder =>
      extruders[0]!; // Fast way for first extruder -> always present!

  int get extruderCount => extruders.length;

  double get zOffset => gCodeMove.homingOrigin[2];

  DateTime? get eta {
    if ((this.print.printDuration) > 0 && (virtualSdCard.progress) > 0) {
      var est =
          print.printDuration / virtualSdCard.progress - print.printDuration;
      return DateTime.now().add(Duration(seconds: est.round()));
    }
    return null;
  }

  /// Expects that the extruder is available prev.
  Extruder extruderFromIndex(int num) {
    return extruders[num]!;
  }

  /// Creates a new Extruder if missing else returns current one!
  Extruder extruderIfAbsence(int num) {
    if (num >= extruders.length) {
      extruders.length = num + 1;
      Extruder element = Extruder(num);
      extruders[num] = element;
      return element;
    }

    Extruder? extruder = extruders[num];
    if (extruder != null) return extruder;

    Extruder element = Extruder(num);
    extruders[num] = element;

    return element;
  }

  @override
  String toString() {
    return 'Printer{toolhead: $toolhead, extruder: $extruder, heaterBed: $heaterBed, printFan: $printFan, gCodeMove: $gCodeMove, print: $print, configFile: $configFile, fans: $fans, temperatureSensors: $temperatureSensors, outputPins: $outputPins, virtualSdCard: $virtualSdCard, queryableObjects: $queryableObjects, gcodeMacros: $gcodeMacros}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Printer &&
          runtimeType == other.runtimeType &&
          toolhead == other.toolhead &&
          heaterBed == other.heaterBed &&
          printFan == other.printFan &&
          gCodeMove == other.gCodeMove &&
          print == other.print &&
          configFile == other.configFile &&
          setEquals(fans, other.fans) &&
          setEquals(temperatureSensors, other.temperatureSensors) &&
          setEquals(outputPins, other.outputPins) &&
          virtualSdCard == other.virtualSdCard &&
          listEquals(queryableObjects, other.queryableObjects) &&
          listEquals(gcodeMacros, other.gcodeMacros) &&
          listEquals(extruders, other.extruders);

  @override
  int get hashCode =>
      toolhead.hashCode ^
      heaterBed.hashCode ^
      printFan.hashCode ^
      gCodeMove.hashCode ^
      print.hashCode ^
      configFile.hashCode ^
      fans.hashIterable ^
      temperatureSensors.hashIterable ^
      outputPins.hashIterable ^
      virtualSdCard.hashCode ^
      queryableObjects.hashCode ^
      gcodeMacros.hashCode^
      extruders.hashIterable;
}
