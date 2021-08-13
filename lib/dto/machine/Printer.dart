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
  Print print = Print();

  ConfigFile configFile = ConfigFile();

  Set<HeaterFan> heaterFans = {};
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
    return 'Printer{state: $state, toolhead: $toolhead, extruder: $extruder, heaterBed: $heaterBed, printFan: $printFan, heaterFans: $heaterFans, virtualSdCard: $virtualSdCard, queryableObjects: $queryableObjects, gcodes: $gcodeMacros}';
  }
}

class Print {
  PrintState state = PrintState.error;
  double totalDuration = 0;
  double printDuration = 0;
  double filamentUsed = 0;
  String message = "";
  String filename = "";

  String get stateName => printStateName(state);
}

class HeaterBed {
  double temperature = 0;
  double target = 0;
  double power = 0;

  @override
  String toString() {
    return 'HeaterBed{temperature: $temperature, target: $target}';
  }
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
}

class VirtualSdCard {
  double progress = 0;
  bool isActive = false;
  int filePosition = 0;
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
}



abstract class Fan {
  double speed = 0;
}

class PrintFan implements Fan {
  @override
  double speed = 0.0;
}

class HeaterFan implements Fan {
  String name;

  @override
  double speed = 0.0;

  HeaterFan(this.name);
}

class TemperatureSensor {
  String name;

  double temperature = 0.0;
  double measuredMinTemp = 0.0;
  double measuredMaxTemp = 0.0;

  TemperatureSensor(this.name);
}

class OutputPin {
  String name;
  double value = 0.0;

  OutputPin(this.name);
}
