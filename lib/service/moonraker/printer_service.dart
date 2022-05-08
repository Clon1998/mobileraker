import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:enum_to_string/enum_to_string.dart';

import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/data/datasource/json_rpc_client.dart';
import 'package:mobileraker/model/hive/machine.dart';
import 'package:mobileraker/data/dto/config/config_file.dart';
import 'package:mobileraker/data/dto/console/command.dart';
import 'package:mobileraker/data/dto/console/console_entry.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/data/dto/machine/fans/controller_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/generic_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/heater_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/named_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/temperature_fan.dart';
import 'package:mobileraker/data/dto/machine/output_pin.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/data/dto/machine/temperature_sensor.dart';
import 'package:mobileraker/data/dto/machine/toolhead.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/ui/components/snackbar/setup_snackbar.dart';
import 'package:mobileraker/util/extensions/double_extension.dart';
import 'package:rxdart/rxdart.dart';
import 'package:stacked_services/stacked_services.dart';

final Set<String> skipGCodes = {'PAUSE', 'RESUME', 'CANCEL_PRINT'};

class PrinterService {
  PrinterService(this._owner) {
    _jRpcClient.addMethodListener(
        _onStatusUpdateHandler, 'notify_status_update');

    _jRpcClient.addMethodListener(
        _onNotifyGcodeResponse, 'notify_gcode_response');

    klippySubscription =
        _owner.klippyService.klipperStream.listen((KlipperInstance value) {
      switch (value.klippyState) {
        case KlipperState.ready:
          if (!_queriedForSession) {
            _queriedForSession = true;
            _printerObjectsList();
          }
          break;
        default:
          _queriedForSession = false;
      }
    });
  }

  final BehaviorSubject<Printer> printerStream = BehaviorSubject<Printer>();
  late final StreamSubscription<KlipperInstance> klippySubscription;

  final Machine _owner;
  final _logger = getLogger('PrinterService');
  final _snackBarService = locator<SnackbarService>();
  final _machineService = locator<MachineService>();

  /// This map defines how different printerObjects will be parsed
  /// For multi-word printer objects (e.g. outputs, temperature_fan...) use the prefix value
  late final Map<String, Function?> _subToPrinterObjects = {
    'toolhead': _updateToolhead,
    'extruder': _updateExtruder,
    'gcode_move': _updateGCodeMove,
    'heater_bed': _updateHeaterBed,
    'virtual_sdcard': _updateVirtualSd,
    'configfile': _updateConfigFile,
    'print_stats': _updatePrintStat,
    'fan': _updatePartFan,
    'heater_fan': _updateHeaterFan,
    'controller_fan': _updateControllerFan,
    'temperature_fan': _updateTemperatureFan,
    'fan_generic': _updateGenericFan,
    'output_pin': _updateOutputPin,
    'temperature_sensor': _updateTemperatureSensor,
  };

  final StreamController<String> _gCodeResponseStreamController =
      StreamController.broadcast();

  bool _queriedForSession = false;

  Stream<String> get gCodeResponseStream =>
      _gCodeResponseStreamController.stream;

  JsonRpcClient get _jRpcClient => _owner.jRpcClient;

  Printer get _latestPrinter {
    return printerStream.hasValue ? printerStream.value : Printer();
  }

  refreshPrinter() {
    _printerObjectsList();
  }

  resumePrint() {
    _jRpcClient.sendJsonRpcWithCallback('printer.print.resume');
  }

  pausePrint() {
    _jRpcClient.sendJsonRpcWithCallback('printer.print.pause');
  }

  cancelPrint() {
    _jRpcClient.sendJsonRpcWithCallback('printer.print.cancel');
  }

  setGcodeOffset({double? x, double? y, double? z, int? move}) {
    List<String> moves = [];
    if (x != null) moves.add('X_ADJUST=$x');
    if (y != null) moves.add('Y_ADJUST=$y');
    if (z != null) moves.add('Z_ADJUST=$z');

    String gcode = 'SET_GCODE_OFFSET ${moves.join(' ')}';
    if (move != null) gcode += ' MOVE=$move';

    gCode(gcode);
  }

  movePrintHead({double? x, double? y, double? z, double feedRate = 100}) {
    List<String> moves = [];
    if (x != null) moves.add(_gcodeMoveCode('X', x));
    if (y != null) moves.add(_gcodeMoveCode('Y', y));
    if (z != null) moves.add(_gcodeMoveCode('Z', z));

    gCode('G91\n' + 'G1 ${moves.join(' ')} F${feedRate * 60}\nG90');
  }

  moveExtruder(double length, [double feedRate = 5]) {
    gCode('M83\n' + 'G1 E$length F${feedRate * 60}');
  }

  homePrintHead(Set<PrinterAxis> axis) {
    if (axis.contains(PrinterAxis.E)) {
      throw FormatException('E axis cant be homed');
    }
    String gcode = 'G28 ';
    if (axis.length < 3) {
      gcode += axis.map(EnumToString.convertToString).join(' ');
    }
    gCode(gcode);
  }

  quadGantryLevel() {
    gCode('QUAD_GANTRY_LEVEL');
  }

  m84() {
    gCode('M84');
  }

  bedMeshLevel() {
    gCode('BED_MESH_CALIBRATE');
  }

  partCoolingFan(double perc) {
    gCode('M106 S${min(255, 255 * perc).toInt()}');
  }

  genericFanFan(String fanName, double perc) {
    gCode('SET_FAN_SPEED  FAN=$fanName SPEED=${perc.toStringAsFixed(2)}');
  }

  outputPin(String pinName, double value) {
    gCode('SET_PIN PIN=$pinName VALUE=${value.toStringAsFixed(2)}');
  }

  gCode(String script) {
    _jRpcClient.sendJsonRpcWithCallback('printer.gcode.script',
        params: {'script': script});
  }

  gCodeMacro(String macro) {
    gCode(macro);
  }

  speedMultiplier(int speed) {
    gCode('M220  S$speed');
  }

  flowMultiplier(int flow) {
    gCode('M221 S$flow');
  }

  setTemperature(String heater, int target) {
    gCode('SET_HEATER_TEMPERATURE  HEATER=$heater TARGET=$target');
  }

  startPrintFile(GCodeFile file) {
    _jRpcClient.sendJsonRpcWithCallback('printer.print.start',
        params: {'filename': file.pathForPrint});
  }

  resetPrintStat() {
    gCode('SDCARD_RESET_FILE');
  }

  Future<List<ConsoleEntry>> gcodeStore() async {
    _logger.i('Fetching cached GCode commands');
    RpcResponse blockingResponse =
        await _jRpcClient.sendJRpcMethod('server.gcode_store');
    if (blockingResponse.hasError) {
      _logger.e(
          'Error while fetching cached GCode commands: ${blockingResponse.err}');
      return List.empty();
    }

    List<dynamic> raw = blockingResponse.response['result']['gcode_store'];
    _logger.i('Received cached GCode commands');
    return List.generate(
        raw.length, (index) => ConsoleEntry.fromJson(raw[index]));
  }

  Future<List<Command>> gcodeHelp() async {
    _logger.i('Fetching available GCode commands');
    RpcResponse blockingResponse =
        await _jRpcClient.sendJRpcMethod('printer.gcode.help');
    if (blockingResponse.hasError) {
      _logger.e(
          'Error while fetching cached GCode commands: ${blockingResponse.err}');
      return List.empty();
    }
    Map<dynamic, dynamic> raw = blockingResponse.response['result'];
    _logger.i('Received ${raw.length} available GCode commands');
    return raw.entries.map((e) => Command(e.key, e.value)).toList();
  }

  _printerObjectsList() {
    // printerStream.value = Printer();
    _logger.i('>>>Querying printers object list');
    _jRpcClient.sendJsonRpcWithCallback('printer.objects.list',
        onReceive: _parsePrinterObjectsList);
  }

  /// Method Handler for registered in the Websocket wrapper.
  /// Handles all incoming messages and maps the correct method to it!

  _onNotifyGcodeResponse(Map<String, dynamic> rawMessage) {
    String message = rawMessage['params'][0];
    _gCodeResponseStreamController.add(message);
  }

  _onStatusUpdateHandler(Map<String, dynamic> rawMessage) {
    Map<String, dynamic> params = rawMessage['params'][0];
    Printer latestPrinter = _latestPrinter;

    params.forEach((key, value) {
      // Splitting here the stuff e.g. for 'temperature_sensor sensor_name'
      List<String> split = key.split(' ');
      String mainObjectType = split[0];
      if (_subToPrinterObjects.containsKey(mainObjectType)) {
        var method = _subToPrinterObjects[mainObjectType];
        if (method != null) {
          if (split.length > 1)
            method(key, params[key], printer: latestPrinter);
          else
            method(params[key], printer: latestPrinter);
        }
      }
    });
    printerStream.add(latestPrinter);
  }

  _parsePrinterObjectsList(response, {err}) {
    if (err != null) return;
    var result = response['result'];
    Printer printer = _latestPrinter;
    _logger.i('<<<Received printer objects list!');
    _logger
        .v('PrinterObjList: ${JsonEncoder.withIndent('  ').convert(result)}');
    List<String> objects = result['objects'].cast<String>();
    List<String> qObjects = [];
    List<String> gCodeMacros = [];

    objects.forEach((element) {
      qObjects.add(element);

      if (element.startsWith('gcode_macro ')) {
        String macro = element.split(' ')[1];
        if (!skipGCodes.contains(macro)) gCodeMacros.add(macro);
      }
    });
    printer.queryableObjects = qObjects;
    printer.gcodeMacros = gCodeMacros;
    _machineService.updateMacrosInSettings(_owner, gCodeMacros);
    _queryPrinterObjects(printer);
  }

  _printerObjectsQuery(dynamic response, Printer printer) {
    _logger.i('<<<Received queried printer objects');
    _logger.v(
        'PrinterObjectsQuery: ${JsonEncoder.withIndent('  ').convert(response)}');
    Map<String, dynamic> data = response['status'];

    data.forEach((key, value) {
      // Splitting here the stuff e.g. for 'temperature_sensor sensor_name'
      List<String> split = key.split(' ');
      String mainObjectType = split[0];
      if (_subToPrinterObjects.containsKey(mainObjectType)) {
        var method = _subToPrinterObjects[mainObjectType];
        if (method != null) {
          if (split.length >
              1) // Multi word objectsType e.g.'temperature_sensor sensor_name'
            method(key, data[key], printer: printer);
          else
            method(data[key], printer: printer);
        }
      }
    });

    printerStream.add(printer);
    // After initally getting all information we can get the data!
    _makeSubscribeRequest(printer);
  }

  _updatePartFan(Map<String, dynamic> fanJson, {required Printer printer}) {
    if (fanJson.containsKey('speed')) printer.printFan.speed = fanJson['speed'];
  }

  _updateHeaterFan(String heaterFanName, Map<String, dynamic> fanJson,
      {required Printer printer}) {
    List<String> split = heaterFanName.split(' ');
    String hName = split.length > 1 ? split.skip(1).join(' ') : split[0];

    NamedFan namedFan = printer.fans.firstWhere(
        (element) => element.name == hName && element is HeaterFan, orElse: () {
      var f = HeaterFan(hName);
      printer.fans.add(f);
      return f;
    });
    if (fanJson.containsKey('speed')) namedFan.speed = fanJson['speed'];
  }

  _updateControllerFan(String fanName, Map<String, dynamic> fanJson,
      {required Printer printer}) {
    List<String> split = fanName.split(' ');
    String hName = split.length > 1 ? split.skip(1).join(' ') : split[0];

    NamedFan namedFan = printer.fans.firstWhere(
        (element) => element.name == hName && element is ControllerFan,
        orElse: () {
      var f = ControllerFan(hName);
      printer.fans.add(f);
      return f;
    });
    if (fanJson.containsKey('speed')) namedFan.speed = fanJson['speed'];
  }

  _updateTemperatureFan(String fanName, Map<String, dynamic> fanJson,
      {required Printer printer}) {
    List<String> split = fanName.split(' ');
    String hName = split.length > 1 ? split.skip(1).join(' ') : split[0];

    NamedFan namedFan = printer.fans.firstWhere(
        (element) => element.name == hName && element is TemperatureFan,
        orElse: () {
      var f = TemperatureFan(hName);
      printer.fans.add(f);
      return f;
    });
    if (fanJson.containsKey('speed')) namedFan.speed = fanJson['speed'];
  }

  _updateGenericFan(String fanName, Map<String, dynamic> fanJson,
      {required Printer printer}) {
    List<String> split = fanName.split(' ');
    String hName = split.length > 1 ? split.skip(1).join(' ') : split[0];

    NamedFan namedFan = printer.fans
        .firstWhere((element) => element.name == hName && element is GenericFan,
            orElse: () {
      var f = GenericFan(hName);
      printer.fans.add(f);
      return f;
    });
    if (fanJson.containsKey('speed')) namedFan.speed = fanJson['speed'];
  }

  _updateTemperatureSensor(String sensor, Map<String, dynamic> sensorJson,
      {required Printer printer}) {
    List<String> split = sensor.split(' ');
    String sName = split.length > 1 ? split.skip(1).join(' ') : split[0];

    TemperatureSensor tempSensor = printer.temperatureSensors
        .firstWhere((element) => element.name == sName, orElse: () {
      var t = TemperatureSensor(sName);
      printer.temperatureSensors.add(t);
      return t;
    });

    if (sensorJson.containsKey('temperature'))
      tempSensor.temperature = sensorJson['temperature'];
    if (sensorJson.containsKey('measured_min_temp'))
      tempSensor.measuredMinTemp = sensorJson['measured_min_temp'];
    if (sensorJson.containsKey('measured_max_temp'))
      tempSensor.measuredMaxTemp = sensorJson['measured_max_temp'];
  }

  _updateOutputPin(String pin, Map<String, dynamic> pinJson,
      {required Printer printer}) {
    List<String> split = pin.split(' ');
    String sName = split.length > 1 ? split.skip(1).join(' ') : split[0];

    OutputPin output = printer.outputPins
        .firstWhere((element) => element.name == sName, orElse: () {
      var t = OutputPin(sName);
      printer.outputPins.add(t);
      return t;
    });

    if (pinJson.containsKey('value')) output.value = pinJson['value'];
  }

  _updateGCodeMove(Map<String, dynamic> gCodeJson, {required Printer printer}) {
    if (gCodeJson.containsKey('speed_factor'))
      printer.gCodeMove.speedFactor = _toPrecision(gCodeJson['speed_factor']);
    if (gCodeJson.containsKey('speed'))
      printer.gCodeMove.speed = gCodeJson['speed'];
    if (gCodeJson.containsKey('extrude_factor'))
      printer.gCodeMove.extrudeFactor =
          _toPrecision(gCodeJson['extrude_factor']);
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

  _updateVirtualSd(Map<String, dynamic> virtualSDJson,
      {required Printer printer}) {
    if (virtualSDJson.containsKey('progress'))
      printer.virtualSdCard.progress = virtualSDJson['progress'];
    if (virtualSDJson.containsKey('is_active'))
      printer.virtualSdCard.isActive = virtualSDJson['is_active'];
    if (virtualSDJson.containsKey('file_position'))
      printer.virtualSdCard.filePosition =
          int.tryParse(virtualSDJson['file_position'].toString()) ?? 0;
  }

  _updatePrintStat(Map<String, dynamic> printStatJson,
      {required Printer printer}) {
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
    if (printStatJson.containsKey('message')) {
      printer.print.message = printStatJson['message'];
      _onMessage(printer.print.message);
    }
  }

  _updateConfigFile(Map<String, dynamic> printStatJson,
      {required Printer printer}) {
    if (printStatJson.containsKey('settings'))
      printer.configFile = ConfigFile.parse(printStatJson['settings']);
    if (printStatJson.containsKey('save_config_pending'))
      printer.configFile.saveConfigPending =
          printStatJson['save_config_pending'];
  }

  _updateHeaterBed(Map<String, dynamic> heatedBedJson,
      {required Printer printer}) {
    if (heatedBedJson.containsKey('temperature'))
      printer.heaterBed.temperature = heatedBedJson['temperature'];
    if (heatedBedJson.containsKey('target'))
      printer.heaterBed.target = heatedBedJson['target'];
    if (heatedBedJson.containsKey('power'))
      printer.heaterBed.power = heatedBedJson['power'];
  }

  _updateExtruder(Map<String, dynamic> extruderJson,
      {required Printer printer}) {
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

  _updateToolhead(Map<String, dynamic> toolHeadJson,
      {required Printer printer}) {
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
      List<String> split = element.split(' ');

      if (_subToPrinterObjects.keys.contains(split[0]))
        queryObjects[element] = null;
    });

    _logger.i('>>>Querying Printer Objects!');

    _jRpcClient.sendJsonRpcWithCallback('printer.objects.query',
        onReceive: (response, {err}) {
      if (err == null) _printerObjectsQuery(response['result'], printer);
    }, params: {'objects': queryObjects});
  }

  /// This method registeres every printer object for websocket updates!
  _makeSubscribeRequest(Printer printer) {
    _logger.i('Subscribing printer objects for ws-updates!');
    Map<String, List<String>?> queryObjects = Map();
    for (var object in printer.queryableObjects) {
      // Splitting here the stuff e.g. for 'temperature_sensor sensor_name'
      List<String> split = object.split(' ');
      String objTypeKey = split[0];
      if (_subToPrinterObjects[objTypeKey] != null) {
        queryObjects[object] =
            null; // This is needed for the subscribe request!
      }
    }

    _jRpcClient.sendJsonRpcWithCallback('printer.objects.subscribe',
        params: {'objects': queryObjects});
  }

  String _gcodeMoveCode(String axis, double value) {
    return '$axis${value <= 0 ? '' : '+'}${value.toStringAsFixed(2)}';
  }

  _onMessage(String message) {
    if (message.isEmpty) return;
    _snackBarService.showCustomSnackBar(
        variant: SnackbarType.warning,
        duration: const Duration(seconds: 5),
        title: 'Print-Message',
        message: message);
  }

  double _toPrecision(double d, [int fraction = 2]) {
    return d.toPrecision(fraction);
  }

  dispose() {
    klippySubscription.cancel();
    printerStream.close();
    _gCodeResponseStreamController.close();
  }
}
