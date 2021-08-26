import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mobileraker/dto/config/ConfigFile.dart';

enum PrinterAxis { X, Y, Z, E }
enum PrinterState { ready, error, shutdown, startup, disconnected }
enum PrintState { standby, printing, paused, complete, error }

String printerStateName(PrinterState printerState) {
  switch (printerState) {
    case PrinterState.ready:
      return "Ready";
    case PrinterState.shutdown:
      return "Shutdown";
    case PrinterState.startup:
      return "Starting";
    case PrinterState.disconnected:
      return "Disconnected";
    case PrinterState.error:
    default:
      return "Error";
  }
}

String printStateName(PrintState printState) {
  switch (printState) {
    case PrintState.standby:
      return "Standby";
    case PrintState.printing:
      return "Printing";
    case PrintState.paused:
      return "Paused";
    case PrintState.complete:
      return "Complete";
    case PrintState.error:
    default:
      return "error";
  }
}

class Printer {
  PrinterState state = PrinterState.error; //Matches ServerState

  Toolhead toolhead = Toolhead();
  Extruder extruder = Extruder();
  HeaterBed heaterBed = HeaterBed();
  PrintFan printFan = PrintFan();
  GCodeMove gCodeMove = GCodeMove();
  PrintStats print = PrintStats();

  ConfigFile configFile = ConfigFile();

  Set<NamedFan> fans = {};

  Set<TemperatureSensor> temperatureSensors = {};
  Set<OutputPin> outputPins = {};

  VirtualSdCard virtualSdCard = VirtualSdCard();

  List<String> queryableObjects = [];
  List<String> gcodeMacros = [];

  String get stateName => printerStateName(state);

  double get zOffset => gCodeMove.homingOrigin[2];

  DateTime? get eta {
    if ((this.print.printDuration) > 0 && (virtualSdCard.progress) > 0) {
      var est =
          print.printDuration / virtualSdCard.progress - print.printDuration;
      return DateTime.now().add(Duration(seconds: est.round()));
    }
    return null;
  }

  static Color stateToColor(PrinterState state) {
    switch (state) {
      case PrinterState.ready:
        return Colors.green;
      case PrinterState.error:
        return Colors.red;
      case PrinterState.shutdown:
      case PrinterState.startup:
      case PrinterState.disconnected:
      default:
        return Colors.orange;
    }
  }

  @override
  String toString() {
    return 'Printer{state: $state, toolhead: $toolhead, extruder: $extruder, heaterBed: $heaterBed, printFan: $printFan, gCodeMove: $gCodeMove, print: $print, configFile: $configFile, fans: $fans, temperatureSensors: $temperatureSensors, outputPins: $outputPins, virtualSdCard: $virtualSdCard, queryableObjects: $queryableObjects, gcodeMacros: $gcodeMacros}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Printer &&
          runtimeType == other.runtimeType &&
          state == other.state &&
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
      state.hashCode ^
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

class PrintStats {
  PrintState state = PrintState.error;
  double totalDuration = 0;
  double printDuration = 0;
  double filamentUsed = 0;
  String message = "";
  String filename = "";

  String get stateName => printStateName(state);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrintStats &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          totalDuration == other.totalDuration &&
          printDuration == other.printDuration &&
          filamentUsed == other.filamentUsed &&
          message == other.message &&
          filename == other.filename;

  @override
  int get hashCode =>
      state.hashCode ^
      totalDuration.hashCode ^
      printDuration.hashCode ^
      filamentUsed.hashCode ^
      message.hashCode ^
      filename.hashCode;
}

class HeaterBed {
  double temperature = 0;
  double target = 0;
  double power = 0;

  @override
  String toString() {
    return 'HeaterBed{temperature: $temperature, target: $target}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeaterBed &&
          runtimeType == other.runtimeType &&
          temperature == other.temperature &&
          target == other.target &&
          power == other.power;

  @override
  int get hashCode => temperature.hashCode ^ target.hashCode ^ power.hashCode;
}

class Extruder {
  double temperature = 0;
  double target = 0;
  double pressureAdvance = 0;
  double smoothTime = 0;
  double power = 0;

  @override
  String toString() {
    return 'Extruder{temperature: $temperature, target: $target, pressureAdvance: $pressureAdvance, smoothTime: $smoothTime}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Extruder &&
          runtimeType == other.runtimeType &&
          temperature == other.temperature &&
          target == other.target &&
          pressureAdvance == other.pressureAdvance &&
          smoothTime == other.smoothTime &&
          power == other.power;

  @override
  int get hashCode =>
      temperature.hashCode ^
      target.hashCode ^
      pressureAdvance.hashCode ^
      smoothTime.hashCode ^
      power.hashCode;
}

class Toolhead {
  Set<PrinterAxis> homedAxes = {};
  List<double> position = [0.0, 0.0, 0.0, 0.0];

  String? activeExtruder;
  double? printTime;
  double? estimatedPrintTime;
  double? maxVelocity;
  double? maxAccel;
  double? maxAccelToDecel;
  double? squareCornerVelocity;

  @override
  String toString() {
    return 'Toolhead{homedAxes: $homedAxes, position: $position, activeExtruder: $activeExtruder, printTime: $printTime, estimatedPrintTime: $estimatedPrintTime, maxVelocity: $maxVelocity, maxAccel: $maxAccel, maxAccelToDecel: $maxAccelToDecel, squareCornerVelocity: $squareCornerVelocity}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Toolhead &&
          runtimeType == other.runtimeType &&
          homedAxes == other.homedAxes &&
          position == other.position &&
          activeExtruder == other.activeExtruder &&
          printTime == other.printTime &&
          estimatedPrintTime == other.estimatedPrintTime &&
          maxVelocity == other.maxVelocity &&
          maxAccel == other.maxAccel &&
          maxAccelToDecel == other.maxAccelToDecel &&
          squareCornerVelocity == other.squareCornerVelocity;

  @override
  int get hashCode =>
      homedAxes.hashCode ^
      position.hashCode ^
      activeExtruder.hashCode ^
      printTime.hashCode ^
      estimatedPrintTime.hashCode ^
      maxVelocity.hashCode ^
      maxAccel.hashCode ^
      maxAccelToDecel.hashCode ^
      squareCornerVelocity.hashCode;
}

class VirtualSdCard {
  double progress = 0;
  bool isActive = false;
  int filePosition = 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VirtualSdCard &&
          runtimeType == other.runtimeType &&
          progress == other.progress &&
          isActive == other.isActive &&
          filePosition == other.filePosition;

  @override
  int get hashCode =>
      progress.hashCode ^ isActive.hashCode ^ filePosition.hashCode;
}

class GCodeMove {
  double speedFactor = 0;
  double speed = 0;
  double extrudeFactor = 0;
  bool absoluteCoordinates = false;
  bool absoluteExtrude = false;
  List<double> homingOrigin = [0.0, 0.0, 0.0, 0.0];
  List<double> position = [0.0, 0.0, 0.0, 0.0];
  List<double> gcodePosition = [0.0, 0.0, 0.0, 0.0];

  int get mmSpeed {
    return (speed / 60 * speedFactor).round();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GCodeMove &&
          runtimeType == other.runtimeType &&
          speedFactor == other.speedFactor &&
          speed == other.speed &&
          extrudeFactor == other.extrudeFactor &&
          absoluteCoordinates == other.absoluteCoordinates &&
          absoluteExtrude == other.absoluteExtrude &&
          homingOrigin == other.homingOrigin &&
          position == other.position &&
          gcodePosition == other.gcodePosition;

  @override
  int get hashCode =>
      speedFactor.hashCode ^
      speed.hashCode ^
      extrudeFactor.hashCode ^
      absoluteCoordinates.hashCode ^
      absoluteExtrude.hashCode ^
      homingOrigin.hashCode ^
      position.hashCode ^
      gcodePosition.hashCode;
}

abstract class Fan {
  double speed = 0;
}

abstract class NamedFan implements Fan {
  String name;

  NamedFan(this.name);
}

class PrintFan implements Fan {
  @override
  double speed = 0.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrintFan &&
          runtimeType == other.runtimeType &&
          speed == other.speed;

  @override
  int get hashCode => speed.hashCode;
}

class HeaterFan implements NamedFan {
  @override
  String name;

  @override
  double speed = 0.0;

  HeaterFan(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeaterFan &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          speed == other.speed;

  @override
  int get hashCode => name.hashCode ^ speed.hashCode;
}

class ControllerFan implements NamedFan {
  @override
  String name;
  @override
  double speed = 0.0;

  ControllerFan(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ControllerFan &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          speed == other.speed;

  @override
  int get hashCode => name.hashCode ^ speed.hashCode;
}

class TemperatureFan implements NamedFan {
  @override
  String name;
  @override
  double speed = 0.0;

  TemperatureFan(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemperatureFan &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          speed == other.speed;

  @override
  int get hashCode => name.hashCode ^ speed.hashCode;
}

class GenericFan implements NamedFan {
  @override
  String name;

  @override
  double speed = 0.0;

  GenericFan(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenericFan &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          speed == other.speed;

  @override
  int get hashCode => name.hashCode ^ speed.hashCode;
}

class TemperatureSensor {
  String name;

  double temperature = 0.0;
  double measuredMinTemp = 0.0;
  double measuredMaxTemp = 0.0;

  TemperatureSensor(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemperatureSensor &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          temperature == other.temperature &&
          measuredMinTemp == other.measuredMinTemp &&
          measuredMaxTemp == other.measuredMaxTemp;

  @override
  int get hashCode =>
      name.hashCode ^
      temperature.hashCode ^
      measuredMinTemp.hashCode ^
      measuredMaxTemp.hashCode;
}

class OutputPin {
  String name;
  double value = 0.0;

  OutputPin(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutputPin &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          value == other.value;

  @override
  int get hashCode => name.hashCode ^ value.hashCode;
}
