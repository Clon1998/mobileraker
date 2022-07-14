import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:get/get.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/data/datasource/json_rpc_client.dart';
import 'package:mobileraker/data/dto/config/config_file.dart';
import 'package:mobileraker/data/dto/console/command.dart';
import 'package:mobileraker/data/dto/console/console_entry.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/data/dto/machine/exclude_object.dart';
import 'package:mobileraker/data/dto/machine/extruder.dart';
import 'package:mobileraker/data/dto/machine/fans/controller_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/generic_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/heater_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/named_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/temperature_fan.dart';
import 'package:mobileraker/data/dto/machine/heater_bed.dart';
import 'package:mobileraker/data/dto/machine/output_pin.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/data/dto/machine/temperature_sensor.dart';
import 'package:mobileraker/data/dto/machine/toolhead.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/ui/components/dialog/setup_dialog_ui.dart';
import 'package:mobileraker/ui/components/snackbar/setup_snackbar.dart';
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
  final _dialogService = locator<DialogService>();
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
    'exclude_object': _updateExcludeObject,
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

  activateExtruder([int extruderIndex = 0]) {
    gCode(
        'ACTIVATE_EXTRUDER EXTRUDER=extruder${extruderIndex > 0 ? extruderIndex : ''}');
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

  pressureAdvance(double pa) {
    gCode('SET_PRESSURE_ADVANCE ADVANCE=${pa.toStringAsFixed(5)}');
  }

  smoothTime(double st) {
    gCode('SET_PRESSURE_ADVANCE SMOOTH_TIME=${st.toStringAsFixed(3)}');
  }

  setVelocityLimit(int vel) {
    gCode('SET_VELOCITY_LIMIT VELOCITY=$vel');
  }

  setAccelerationLimit(int accel) {
    gCode('SET_VELOCITY_LIMIT ACCEL=$accel');
  }

  setSquareCornerVelocityLimit(double sqVel) {
    gCode('SET_VELOCITY_LIMIT SQUARE_CORNER_VELOCITY=$sqVel');
  }

  setAccelToDecel(int accelDecel) {
    gCode('SET_VELOCITY_LIMIT ACCEL_TO_DECEL=$accelDecel');
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

  Future<void> _temperatureStore(Printer printer) async {
    _logger.i('Fetching cached temperature store data');
    RpcResponse blockingResponse =
        await _jRpcClient.sendJRpcMethod('server.temperature_store');
    if (blockingResponse.hasError) {
      _logger.e(
          'Error while fetching cached temperature store: ${blockingResponse.err}');
      return;
    }

    Map<String, dynamic> raw = blockingResponse.response['result'];
    List<String> sensors = raw.keys
        .toList(); // temperature_sensor <NAME>, extruder, heater_bed, temperature_fan
    _logger.i('Received cached temperature store for $sensors');

    raw.forEach((key, value) {
      _parseObjectType(key, raw, printer);
    });
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

  excludeObject(ParsedObject objToExc) {
    gCode('EXCLUDE_OBJECT NAME=${objToExc.name}');
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

      _parseObjectType(key, params, latestPrinter);
    });
    printerStream.add(latestPrinter);
  }

  _parseObjectType(String key, Map<String, dynamic> json, Printer printer) {
    // Splitting here the stuff e.g. for 'temperature_sensor sensor_name'
    List<String> split = key.split(' ');
    String mainObjectType = split[0];
    try {
      if (_subToPrinterObjects.containsKey(mainObjectType)) {
        var method = _subToPrinterObjects[mainObjectType];
        if (method != null) {
          if (split.length > 1)
            method(key, json[key], printer: printer);
          else
            method(json[key], printer: printer);
        }
      } else if (mainObjectType.startsWith('extruder')) {
        // Note that extruder will be handled above!
        _updateExtruder(json[key],
            printer: printer,
            num: int.tryParse(mainObjectType.substring(8)) ?? 0);
      }
    } catch (e, s) {
      _logger.e('Error while parsing $key object', e, s);
      _logger.e(e);
      _logger.e(s);
      _snackBarService.showCustomSnackBar(
          variant: SnackbarType.error,
          duration: const Duration(seconds: 20),
          title: '$key - Parsing error',
          message: 'Could not parse: $e',
          mainButtonTitle: "Details",
          onMainButtonTapped: () {
            Get.closeCurrentSnackbar();
            _dialogService.showCustomDialog(
                variant: DialogType.stackTrace,
                title: '$key - Parsing error',
                description: s.toString());
          });
    }
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

  _printerObjectsQuery(dynamic response, Printer printer) async {
    _logger.i('<<<Received queried printer objects');
    _logger.v(
        'PrinterObjectsQuery: ${JsonEncoder.withIndent('  ').convert(response)}');
    Map<String, dynamic> data = response['status'];

    data.forEach((key, value) {
      _parseObjectType(key, data, printer);
    });

    printerStream.add(printer);
    await _temperatureStore(printer);
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

    // Update temp cache for graphs!
    DateTime now = DateTime.now();
    if (now.difference(tempSensor.lastHistory).inSeconds >= 1) {
      if ((tempSensor.temperatureHistory?.length ?? 0) >= 1200)
        tempSensor.temperatureHistory?.removeAt(0);
      tempSensor.temperatureHistory?.add(tempSensor.temperature);
      tempSensor.lastHistory = now;
    }

    // Ill just put the tempCache here because I am lazy.. kinda sucks but who cares
    if (sensorJson.containsKey('temperatures'))
      tempSensor.temperatureHistory =
          (sensorJson['temperatures'] as List<dynamic>).cast<double>();
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
    HeaterBed heaterBed = printer.heaterBed;
    if (heatedBedJson.containsKey('temperature'))
      heaterBed.temperature = heatedBedJson['temperature'];
    if (heatedBedJson.containsKey('target'))
      heaterBed.target = heatedBedJson['target'];
    if (heatedBedJson.containsKey('power'))
      heaterBed.power = heatedBedJson['power'];

    // Update temp cache for graphs!
    DateTime now = DateTime.now();
    if (now.difference(heaterBed.lastHistory).inSeconds >= 1) {
      if ((heaterBed.temperatureHistory?.length ?? 0) >= 1200)
        heaterBed.temperatureHistory?.removeAt(0);
      heaterBed.temperatureHistory?.add(heaterBed.temperature);
      heaterBed.powerHistory?.removeAt(0);
      heaterBed.powerHistory?.add(heaterBed.power);
      heaterBed.targetHistory?.removeAt(0);
      heaterBed.targetHistory?.add(heaterBed.target);
      heaterBed.lastHistory = now;
    }

    // Ill just put the tempCache here because I am lazy.. kinda sucks but who cares
    if (heatedBedJson.containsKey('temperatures'))
      heaterBed.temperatureHistory =
          (heatedBedJson['temperatures'] as List<dynamic>).cast<double>();
    if (heatedBedJson.containsKey('targets'))
      heaterBed.targetHistory =
          (heatedBedJson['targets'] as List<dynamic>).cast<double>();
    if (heatedBedJson.containsKey('powers'))
      heaterBed.powerHistory =
          (heatedBedJson['powers'] as List<dynamic>).cast<double>();
  }

  _updateExtruder(Map<String, dynamic> extruderJson,
      {required Printer printer, int num = 0}) {
    Extruder extruder = printer.extruderIfAbsence(num);
    if (extruderJson.containsKey('temperature'))
      extruder.temperature = extruderJson['temperature'];
    if (extruderJson.containsKey('target'))
      extruder.target = extruderJson['target'];
    if (extruderJson.containsKey('pressure_advance'))
      extruder.pressureAdvance = extruderJson['pressure_advance'];
    if (extruderJson.containsKey('smooth_time'))
      extruder.smoothTime = extruderJson['smooth_time'];
    if (extruderJson.containsKey('power'))
      extruder.power = extruderJson['power'];

    // Update temp cache for graphs!
    DateTime now = DateTime.now();
    if (now.difference(extruder.lastHistory).inSeconds >= 1) {
      if ((extruder.temperatureHistory?.length ?? 0) >= 1200)
        extruder.temperatureHistory?.removeAt(0);
      extruder.temperatureHistory?.add(extruder.temperature);
      extruder.powerHistory?.removeAt(0);
      extruder.powerHistory?.add(extruder.power);
      extruder.targetHistory?.removeAt(0);
      extruder.targetHistory?.add(extruder.target);
      extruder.lastHistory = now;
    }

    // Ill just put the tempCache here because I am lazy.. kinda sucks but who cares
    if (extruderJson.containsKey('temperatures'))
      extruder.temperatureHistory =
          (extruderJson['temperatures'] as List<dynamic>).cast<double>();
    if (extruderJson.containsKey('targets'))
      extruder.targetHistory =
          (extruderJson['targets'] as List<dynamic>).cast<double>();
    if (extruderJson.containsKey('powers'))
      extruder.powerHistory =
          (extruderJson['powers'] as List<dynamic>).cast<double>();
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

  _updateExcludeObject(Map<String, dynamic> json, {required Printer printer}) {
    if (json.containsKey('current_object'))
      printer.excludeObject.currentObject = json['current_object'];

    if (json.containsKey('excluded_objects')) {
      List<dynamic> _excludedObjects = json['excluded_objects'];

      printer.excludeObject.excludedObjects =
          _excludedObjects.map((e) => e as String).toList();
    }
    if (json.containsKey('objects')) {
      List<dynamic> _objects = json['objects'];
      List<ParsedObject> objects = [];
      for (Map<String, dynamic> e in _objects) {
        String name = e['name'];
        List<double> center;
        List<List<double>> polygons;
        if (e.containsKey('center')) {
          List<dynamic> _center = e['center'];
          center = _center.cast<double>();
        } else {
          center = [];
        }
        if (e.containsKey('polygon')) {
          List<dynamic> _polygons = e['polygon'];
          polygons = _polygons.map((e) {
            List<dynamic> list = e as List<dynamic>;
            return list.cast<double>();
          }).toList();
        } else {
          polygons = [];
        }

        objects.add(ParsedObject.fromList(
            name: name, center: center, polygons: polygons));
      }

      printer.excludeObject.objects = objects;
    }
    _logger.v('New exclude_printer: ${printer.excludeObject}');
  }

  Map<String, List<String>?> _queryPrinterObjectJson(Printer printer) {
    Map<String, List<String>?> queryObjects = Map();
    printer.queryableObjects.forEach((ele) {
      // Splitting here the stuff e.g. for 'temperature_sensor sensor_name'
      List<String> split = ele.split(' ');
      String objTypeKey = split[0];

      if (_subToPrinterObjects.keys.contains(objTypeKey))
        queryObjects[ele] = null;
      else if (ele.startsWith('extruder')) // used for multiple extruders!
        queryObjects[ele] = null;
    });
    return queryObjects;
  }

  /// Query the state of queryable printer objects once!
  _queryPrinterObjects(Printer printer) {
    Map<String, List<String>?> queryObjects = _queryPrinterObjectJson(printer);

    _logger.i('>>>Querying Printer Objects!');

    _jRpcClient.sendJsonRpcWithCallback('printer.objects.query',
        onReceive: (response, {err}) {
      if (err == null) _printerObjectsQuery(response['result'], printer);
    }, params: {'objects': queryObjects});
  }

  /// This method registeres every printer object for websocket updates!
  _makeSubscribeRequest(Printer printer) {
    _logger.i('Subscribing printer objects for ws-updates!');
    Map<String, List<String>?> queryObjects = _queryPrinterObjectJson(printer);

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
