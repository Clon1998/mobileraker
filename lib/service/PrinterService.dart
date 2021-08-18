import 'dart:convert';
import 'dart:math';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/foundation.dart';
import 'package:mobileraker/WebSocket.dart';
import 'package:mobileraker/app/AppSetup.logger.dart';
import 'package:mobileraker/dto/config/ConfigFile.dart';
import 'package:mobileraker/dto/machine/Printer.dart';
import 'package:rxdart/rxdart.dart';

final Set<String> skipGCodes = {"PAUSE", "RESUME", "CANCEL_PRINT"};

class PrinterService {
  final WebSocketWrapper _webSocket;
  final _logger = getLogger('PrinterService');

  ObserverList<MapEntry<String, Function>> _statusUpdateListener =
      ObserverList();

  late final Map<String, Function?> subToPrinterObjects;
  final BehaviorSubject<Printer> printerStream = BehaviorSubject<Printer>();

  PrinterService(this._webSocket) {
    subToPrinterObjects = {
      'toolhead': _updateToolhead,
      'extruder': _updateExtruder,
      'gcode_move': _updateGCodeMove,
      'heater_bed': _updateHeaterBed,
      'fan': _updatePartFan,
      'virtual_sdcard': _updateVirtualSd,
      'configfile': null,
      'print_stats': _updatePrintStat,
      'heater_fan': _updateHeaterFan,
      'output_pin': _updateOutputPin,
      'temperature_sensor': _updateTemperatureSensor,
    };

    _webSocket.addMethodListener(
        _onStatusUpdateHandler, "notify_status_update");
    _webSocket.stateStream.listen((value) {
      switch (value) {
        case WebSocketState.connected:
          _fetchPrinter();
          break;
        default:
      }
    });
  }

  _fetchPrinter() {
    _logger.i("Fetching printer Info");
    printerStream.value = Printer();
    _webSocket.sendObject("printer.info", _printerInfo);
    _webSocket.sendObject("printer.objects.list", _printerObjectsList);
  }

  refreshPrinter() {
    _fetchPrinter();
  }

  /**
   * Adds a callback to the notify_status_update method of moonraker
   */
  addStatusUpdateListener(Function callback, [String object = ""]) {
    _statusUpdateListener.add(MapEntry(object, callback));
  }

  _onStatusUpdateHandler(Map<String, dynamic> rawMessage) {
    Map<String, dynamic> params = rawMessage['params'][0];
    Printer latestPrinter = _getLatestPrinter();
    for (MapEntry<String, Function> listener in _statusUpdateListener) {
      if (params[listener.key] != null) if (listener.key.split(" ").length > 1)
        listener.value(listener.key, params[listener.key],
            printer: latestPrinter);
      else
        listener.value(params[listener.key], printer: latestPrinter);
    }
    printerStream.add(latestPrinter);
  }

  _printerInfo(response) {
    Printer printer = _getLatestPrinter();
    _logger.v('PrinterInfo: ${JsonEncoder.withIndent('  ').convert(response)}');
    var fromString =
        EnumToString.fromString(PrinterState.values, response['state']);
    printer.state = fromString ?? PrinterState.error;
    printerStream.add(printer);
  }

  _printerObjectsList(response) {
    Printer printer = _getLatestPrinter();
    _logger
        .v('PrinterObjList: ${JsonEncoder.withIndent('  ').convert(response)}');
    List<String> objects = response['objects'].cast<String>();

    objects.forEach((element) {
      printer.queryableObjects.add(element);

      if (element.startsWith("gcode_macro ")) {
        String macro = element.split(" ")[1];
        if (!skipGCodes.contains(macro)) printer.gcodeMacros.add(macro);
      }
    });
    printerStream.add(printer);

    _queryPrinterObjects(printer);
    _makeSubscribeRequest(printer);
  }

  _printerObjectsQuery(response) {
    Printer printer = _getLatestPrinter();
    _logger.v(
        'PrinterObjectsQuery: ${JsonEncoder.withIndent('  ').convert(response)}');
    Map<String, dynamic> data = response['status'];
    if (data.containsKey('toolhead')) {
      var toolHeadJson = data['toolhead'];

      _updateToolhead(toolHeadJson, printer: printer);
    }

    if (data.containsKey('extruder')) {
      var extruderJson = data['extruder'];

      _updateExtruder(extruderJson, printer: printer);
    }

    if (data.containsKey('heater_bed')) {
      var heatedBedJson = data['heater_bed'];

      _updateHeaterBed(heatedBedJson, printer: printer);
    }

    if (data.containsKey('virtual_sdcard')) {
      var virtualSDJson = data['virtual_sdcard'];

      _updateVirtualSd(virtualSDJson, printer: printer);
    }

    if (data.containsKey('gcode_move')) {
      var gCodeJson = data['gcode_move'];

      _updateGCodeMove(gCodeJson, printer: printer);
    }

    if (data.containsKey('print_stats')) {
      var printStateJson = data['print_stats'];

      _updatePrintStat(printStateJson, printer: printer);
    }

    if (data.containsKey('configfile')) {
      var printConfigJson = data['configfile'];
      _updateConfigFile(printConfigJson, printer: printer);
    }

    //Partcooling Fan
    if (data.containsKey('fan')) {
      _updatePartFan(data, printer: printer);
    }

    var heaterFans =
        data.keys.where((element) => element.startsWith('heater_fan'));
    if (heaterFans.isNotEmpty) {
      for (var heaterFanName in heaterFans) {
        var fanJson = data[heaterFanName];
        _updateHeaterFan(heaterFanName, fanJson, printer: printer);
      }
    }

    var temperatureSensors =
        data.keys.where((element) => element.startsWith('temperature_sensor'));
    if (temperatureSensors.isNotEmpty) {
      for (var sensor in temperatureSensors) {
        var sensorJson = data[sensor];
        _updateTemperatureSensor(sensor, sensorJson, printer: printer);
      }
    }

    var outputPins =
        data.keys.where((element) => element.startsWith('output_pin'));
    if (outputPins.isNotEmpty) {
      for (var pins in outputPins) {
        var pinJson = data[pins];
        _updateOutputPin(pins, pinJson, printer: printer);
      }
    }

    printerStream.add(printer);
  }

  void _updateHeaterFan(String heaterFanName, Map<String, dynamic> fanJson,
      {Printer? printer}) {
    printer ??= _getLatestPrinter();
    List<String> split = heaterFanName.split(" ");
    String hName = split.length > 1 ? split[1] : split[0];

    HeaterFan heaterFan = printer.heaterFans
        .firstWhere((element) => element.name == hName, orElse: () {
      var f = HeaterFan(hName);
      printer!.heaterFans.add(f);
      return f;
    });
    if (fanJson.containsKey('speed')) heaterFan.speed = fanJson['speed'];
    printer.heaterFans.add(heaterFan);
  }

  void _updatePartFan(Map<String, dynamic> fanJson, {Printer? printer}) {
    printer ??= _getLatestPrinter();
    if (fanJson.containsKey('speed')) printer.printFan.speed = fanJson['speed'];
  }

  void _updateTemperatureSensor(String sensor, Map<String, dynamic> sensorJson,
      {Printer? printer}) {
    printer ??= _getLatestPrinter();
    List<String> split = sensor.split(" ");
    String sName = split.length > 1 ? split[1] : split[0];

    TemperatureSensor tempSensor = printer.temperatureSensors
        .firstWhere((element) => element.name == sName, orElse: () {
      var t = TemperatureSensor(sName);
      printer!.temperatureSensors.add(t);
      return t;
    });

    if (sensorJson.containsKey('temperature'))
      tempSensor.temperature = sensorJson['temperature'];
    if (sensorJson.containsKey('measured_min_temp'))
      tempSensor.measuredMinTemp = sensorJson['measured_min_temp'];
    if (sensorJson.containsKey('measured_max_temp'))
      tempSensor.measuredMaxTemp = sensorJson['measured_max_temp'];
  }

  void _updateOutputPin(String pin, Map<String, dynamic> pinJson,
      {Printer? printer}) {
    printer ??= _getLatestPrinter();
    List<String> split = pin.split(" ");
    String sName = split.length > 1 ? split[1] : split[0];

    OutputPin output = printer.outputPins
        .firstWhere((element) => element.name == sName, orElse: () {
      var t = OutputPin(sName);
      printer!.outputPins.add(t);
      return t;
    });

    if (pinJson.containsKey('value')) output.value = pinJson['value'];
  }

  _updateGCodeMove(Map<String, dynamic> gCodeJson, {Printer? printer}) {
    printer ??= _getLatestPrinter();
    if (gCodeJson.containsKey('speed_factor'))
      printer.gCodeMove.speedFactor = gCodeJson['speed_factor'];
    if (gCodeJson.containsKey('speed'))
      printer.gCodeMove.speed = gCodeJson['speed'];
    if (gCodeJson.containsKey('extrude_factor'))
      printer.gCodeMove.extrudeFactor = gCodeJson['extrude_factor'];
    if (gCodeJson.containsKey('absolute_coordinates'))
      printer.gCodeMove.absoluteCoordinates = gCodeJson['absolute_coordinates'];
    if (gCodeJson.containsKey('absolute_extrude'))
      printer.gCodeMove.absoluteExtrude = gCodeJson['absolute_extrude'];

    if (gCodeJson.containsKey('position')) {
      List<double> posJson = gCodeJson['position'].cast<double>();
      printer.gCodeMove.position = posJson;
    }
    if (gCodeJson.containsKey('homing_origin')) {
      List<double> posJson = gCodeJson['homing_origin'].cast<double>();
      printer.gCodeMove.homingOrigin = posJson;
    }
    if (gCodeJson.containsKey('gcode_position')) {
      List<double> posJson = gCodeJson['gcode_position'].cast<double>();
      printer.gCodeMove.gcodePosition = posJson;
    }
  }

  _updateVirtualSd(Map<String, dynamic> virtualSDJson, {Printer? printer}) {
    printer ??= _getLatestPrinter();
    if (virtualSDJson.containsKey('progress'))
      printer.virtualSdCard.progress = virtualSDJson['progress'];
    if (virtualSDJson.containsKey('is_active'))
      printer.virtualSdCard.isActive = virtualSDJson['is_active'];
    if (virtualSDJson.containsKey('file_position'))
      printer.virtualSdCard.filePosition =
          int.parse(virtualSDJson['file_position'].toString());
  }

  _updatePrintStat(Map<String, dynamic> printStatJson, {Printer? printer}) {
    printer ??= _getLatestPrinter();
    if (printStatJson.containsKey('state'))
      printer.print.state =
          EnumToString.fromString(PrintState.values, printStatJson['state'])!;
    if (printStatJson.containsKey('filename'))
      printer.print.filename = printStatJson['filename'];
    if (printStatJson.containsKey('total_duration'))
      printer.print.totalDuration = printStatJson['total_duration'];
    if (printStatJson.containsKey('print_duration'))
      printer.print.printDuration = printStatJson['print_duration'];
    if (printStatJson.containsKey('filament_used'))
      printer.print.filamentUsed = printStatJson['filament_used'];
    if (printStatJson.containsKey('message'))
      printer.print.message = printStatJson['message'];
  }

  _updateConfigFile(Map<String, dynamic> printStatJson, {Printer? printer}) {
    printer ??= _getLatestPrinter();

    if (printStatJson.containsKey('settings'))
      printer.configFile = ConfigFile.parse(printStatJson['settings']);
    if (printStatJson.containsKey('save_config_pending'))
      printer.configFile.saveConfigPending =
          printStatJson['save_config_pending'];
  }

  _updateHeaterBed(Map<String, dynamic> heatedBedJson, {Printer? printer}) {
    printer ??= _getLatestPrinter();
    if (heatedBedJson.containsKey('temperature'))
      printer.heaterBed.temperature = heatedBedJson['temperature'];
    if (heatedBedJson.containsKey('target'))
      printer.heaterBed.target = heatedBedJson['target'];
    if (heatedBedJson.containsKey('power'))
      printer.heaterBed.power = heatedBedJson['power'];
  }

  _updateExtruder(Map<String, dynamic> extruderJson, {Printer? printer}) {
    printer ??= _getLatestPrinter();
    if (extruderJson.containsKey('temperature'))
      printer.extruder.temperature = extruderJson['temperature'];
    if (extruderJson.containsKey('target'))
      printer.extruder.target = extruderJson['target'];
    if (extruderJson.containsKey('pressure_advance'))
      printer.extruder.pressureAdvance = extruderJson['pressure_advance'];
    if (extruderJson.containsKey('smooth_time'))
      printer.extruder.smoothTime = extruderJson['smooth_time'];
    if (extruderJson.containsKey('power'))
      printer.extruder.power = extruderJson['power'];
  }

  _updateToolhead(Map<String, dynamic> toolHeadJson, {Printer? printer}) {
    printer ??= _getLatestPrinter();
    if (toolHeadJson.containsKey('homed_axes')) {
      String hAxes = toolHeadJson['homed_axes'];
      Set<PrinterAxis> homed = {};
      hAxes.toUpperCase().split('').forEach(
          (e) => homed.add(EnumToString.fromString(PrinterAxis.values, e)!));
      printer.toolhead.homedAxes = homed;
    }

    if (toolHeadJson.containsKey('position')) {
      List<double> posJson = toolHeadJson['position'].cast<double>();
      printer.toolhead.position = posJson;
    }
    if (toolHeadJson.containsKey('print_time'))
      printer.toolhead.printTime = toolHeadJson['print_time'];
    if (toolHeadJson.containsKey('max_velocity'))
      printer.toolhead.maxVelocity = toolHeadJson['max_velocity'];
    if (toolHeadJson.containsKey('max_accel'))
      printer.toolhead.maxAccel = toolHeadJson['max_accel'];
    if (toolHeadJson.containsKey('max_accel_to_decel'))
      printer.toolhead.maxAccelToDecel = toolHeadJson['max_accel_to_decel'];
    if (toolHeadJson.containsKey('extruder'))
      printer.toolhead.activeExtruder = toolHeadJson['extruder'];
    if (toolHeadJson.containsKey('square_corner_velocity'))
      printer.toolhead.squareCornerVelocity =
          toolHeadJson['square_corner_velocity'];
    if (toolHeadJson.containsKey('estimated_print_time'))
      printer.toolhead.estimatedPrintTime =
          toolHeadJson['estimated_print_time'];
  }

  _queryPrinterObjects(Printer printer) {
    Map<String, List<String>?> queryObjects = Map();
    printer.queryableObjects.forEach((element) {
      List<String> split = element.split(" ");

      if (subToPrinterObjects.keys.contains(split[0]))
        queryObjects[element] = null;
    });

    _webSocket.sendObject("printer.objects.query", _printerObjectsQuery,
        params: {'objects': queryObjects});
  }

  _makeSubscribeRequest(Printer printer) {
    Map<String, List<String>?> queryObjects = Map();
    for (var obj in printer.queryableObjects) {
      List<String> split = obj.split(" ");
      // Splitting here the stuff e.g. for 'temperature_sensor sensor_name'
      String objType = split[0];
      if (subToPrinterObjects[objType] != null) {
        addStatusUpdateListener(subToPrinterObjects[objType]!, obj);
        queryObjects[obj] = null;
      }
    }

    _webSocket.sendObject("printer.objects.subscribe", null,
        params: {'objects': queryObjects});
  }

  // PRINTER PUBLIC METHODS

  resumePrint() {
    _webSocket.sendObject("printer.print.resume", null);
  }

  pausePrint() {
    _webSocket.sendObject("printer.print.pause", null);
  }

  cancelPrint() {
    _webSocket.sendObject("printer.print.cancel", null);
  }

  setGcodeOffset({double? x, double? y, double? z, int? move}) {
    List<String> moves = [];
    if (x != null) moves.add("X_ADJUST=$x");
    if (y != null) moves.add("Y_ADJUST=$y");
    if (z != null) moves.add("Z_ADJUST=$z");

    String gcode = "SET_GCODE_OFFSET ${moves.join(" ")}";
    if (move != null) gcode += " MOVE=$move";

    _webSocket
        .sendObject("printer.gcode.script", null, params: {'script': gcode});
  }

  movePrintHead({x, y, z}) {
    List<String> moves = [];
    if (x != null) moves.add(_gcodeMoveCode("X", x));
    if (y != null) moves.add(_gcodeMoveCode("Y", y));
    if (z != null) moves.add(_gcodeMoveCode("Z", z));

    String gcode = "G91\n" + "G1 ${moves.join(" ")} F${100 * 60}\nG90";
    _webSocket
        .sendObject("printer.gcode.script", null, params: {'script': gcode});
  }

  moveExtruder(double length, [double feedRate = 5]) {
    String gcode = "M83\n" + "G1 E$length F${feedRate * 60}";
    _webSocket
        .sendObject("printer.gcode.script", null, params: {'script': gcode});
  }

  homePrintHead(Set<PrinterAxis> axis) {
    if (axis.contains(PrinterAxis.E)) {
      throw FormatException("E axis cant be homed");
    }
    String gcode = "G28 ";
    if (axis.length < 3) {
      gcode += axis.map(EnumToString.convertToString).join(" ");
    }

    _webSocket
        .sendObject("printer.gcode.script", null, params: {'script': gcode});
  }

  quadGantryLevel() {
    _webSocket.sendObject("printer.gcode.script", null,
        params: {'script': "QUAD_GANTRY_LEVEL"});
  }

  bedMeshLevel() {
    _webSocket.sendObject("printer.gcode.script", null,
        params: {'script': "BED_MESH_CALIBRATE"});
  }

  partCoolingFan(double perc) {
    _webSocket.sendObject("printer.gcode.script", null,
        params: {'script': "M106 S${min(255, 255 * perc).toInt()}"});
  }

  outputPin(String pinName, double perc) {
    _webSocket.sendObject("printer.gcode.script", null,
        params: {'script': "SET_PIN PIN=$pinName VALUE=${perc.toInt()}"});
  }

  gCodeMacro(String macro) {
    _webSocket
        .sendObject("printer.gcode.script", null, params: {'script': macro});
  }

  setTemperature(String heater, int target) {
    String gcode = "SET_HEATER_TEMPERATURE  HEATER=$heater TARGET=$target";

    _webSocket
        .sendObject("printer.gcode.script", null, params: {'script': gcode});
  }

  String _gcodeMoveCode(String axis, double value) {
    return "$axis${value <= 0 ? '' : '+'}${value.toStringAsFixed(2)}";
  }

  Printer _getLatestPrinter() {
    return printerStream.hasValue ? printerStream.value : Printer();
  }
}
