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

class Printer {
  Toolhead toolhead = Toolhead();
  Extruder extruder = Extruder();
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

  double get zOffset => gCodeMove.homingOrigin[2];

  DateTime? get eta {
    if ((this.print.printDuration) > 0 && (virtualSdCard.progress) > 0) {
      var est =
          print.printDuration / virtualSdCard.progress - print.printDuration;
      return DateTime.now().add(Duration(seconds: est.round()));
    }
    return null;
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
          extruder == other.extruder &&
          heaterBed == other.heaterBed &&
          printFan == other.printFan &&
          gCodeMove == other.gCodeMove &&
          print == other.print &&
          configFile == other.configFile &&
          fans == other.fans &&
          temperatureSensors == other.temperatureSensors &&
          outputPins == other.outputPins &&
          virtualSdCard == other.virtualSdCard &&
          queryableObjects == other.queryableObjects &&
          gcodeMacros == other.gcodeMacros;

  @override
  int get hashCode =>
      toolhead.hashCode ^
      extruder.hashCode ^
      heaterBed.hashCode ^
      printFan.hashCode ^
      gCodeMove.hashCode ^
      print.hashCode ^
      configFile.hashCode ^
      fans.hashCode ^
      temperatureSensors.hashCode ^
      outputPins.hashCode ^
      virtualSdCard.hashCode ^
      queryableObjects.hashCode ^
      gcodeMacros.hashCode;
}
