/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/config/config_file.dart';
import 'package:mobileraker/data/dto/console/command.dart';
import 'package:mobileraker/data/dto/console/console_entry.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/data/dto/jrpc/rpc_response.dart';
import 'package:mobileraker/data/dto/machine/bed_screw.dart';
import 'package:mobileraker/data/dto/machine/display_status.dart';
import 'package:mobileraker/data/dto/machine/exclude_object.dart';
import 'package:mobileraker/data/dto/machine/fans/controller_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/generic_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/heater_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/print_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/temperature_fan.dart';
import 'package:mobileraker/data/dto/machine/gcode_move.dart';
import 'package:mobileraker/data/dto/machine/heaters/extruder.dart';
import 'package:mobileraker/data/dto/machine/heaters/generic_heater.dart';
import 'package:mobileraker/data/dto/machine/heaters/heater_bed.dart';
import 'package:mobileraker/data/dto/machine/leds/addressable_led.dart';
import 'package:mobileraker/data/dto/machine/leds/dumb_led.dart';
import 'package:mobileraker/data/dto/machine/leds/led.dart';
import 'package:mobileraker/data/dto/machine/manual_probe.dart';
import 'package:mobileraker/data/dto/machine/motion_report.dart';
import 'package:mobileraker/data/dto/machine/output_pin.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/data/dto/machine/temperature_sensor.dart';
import 'package:mobileraker/data/dto/machine/toolhead.dart';
import 'package:mobileraker/data/dto/machine/virtual_sd_card.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/exceptions.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/service/ui/snackbar_service.dart';
import 'package:mobileraker/util/extensions/ref_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stringr/stringr.dart';

part 'printer_service.g.dart';

final Set<String> skipGCodes = {'PAUSE', 'RESUME', 'CANCEL_PRINT'};

@riverpod
PrinterService printerService(PrinterServiceRef ref, String machineUUID) {
  return PrinterService(ref, machineUUID);
}

@riverpod
Stream<Printer> printer(PrinterRef ref, String machineUUID) {
  ref.keepAlive();
  return ref.watch(printerServiceProvider(machineUUID)).printerStream;
}

@riverpod
PrinterService printerServiceSelected(PrinterServiceSelectedRef ref) {
  return ref.watch(printerServiceProvider(
      ref.watch(selectedMachineProvider).valueOrNull!.uuid));
}

@riverpod
Stream<Printer> printerSelected(PrinterSelectedRef ref) async* {
  try {
    var machine = await ref.watchWhereNotNull(selectedMachineProvider);

    yield* ref.watchAsSubject(printerProvider(machine.uuid));
  } on StateError catch (_) {
    // Just catch it. It is expected that the future/where might not complete!
  }
}

class PrinterService {
  PrinterService(AutoDisposeRef ref, this.ownerUUID)
      : _jRpcClient = ref.watch(jrpcClientProvider(ownerUUID)),
        _machineService = ref.watch(machineServiceProvider),
        _snackBarService = ref.watch(snackBarServiceProvider),
        _dialogService = ref.watch(dialogServiceProvider) {
    ref.onDispose(dispose);

    ref.listen<AsyncValue<KlipperInstance>>(klipperProvider(ownerUUID),
        (previous, next) {
      next.whenOrNull(data: (value) {
        switch (value.klippyState) {
          case KlipperState.ready:
            if (!_queriedForSession) {
              _queriedForSession = true;
              refreshPrinter();
            }
            break;
          default:
            _queriedForSession = false;
        }
      });
    }, fireImmediately: true);
  }

  final String ownerUUID;

  final SnackBarService _snackBarService;

  final DialogService _dialogService;

  final JsonRpcClient _jRpcClient;

  final MachineService _machineService;

  final StreamController<Printer> _printerStreamCtler = StreamController();

  bool get disposed => _printerStreamCtler.isClosed;

  Stream<Printer> get printerStream => _printerStreamCtler.stream;

  /// This map defines how different printerObjects will be parsed
  /// For multi-word printer objects (e.g. outputs, temperature_fan...) use the prefix value
  late final Map<String, Function?> _subToPrinterObjects = {
    'toolhead': _updateToolhead,
    'extruder': _updateExtruder,
    'gcode_move': _updateGCodeMove,
    'motion_report': _updateMotionReport,
    'display_status': _updateDisplayStatus,
    'heater_bed': _updateHeaterBed,
    'virtual_sdcard': _updateVirtualSd,
    'configfile': _updateConfigFile,
    'print_stats': _updatePrintStat,
    'fan': _updatePrintFan,
    'heater_fan': _updateHeaterFan,
    'controller_fan': _updateControllerFan,
    'temperature_fan': _updateTemperatureFan,
    'fan_generic': _updateGenericFan,
    'output_pin': _updateOutputPin,
    'temperature_sensor': _updateTemperatureSensor,
    'exclude_object': _updateExcludeObject,
    'led': _updateLed,
    'neopixel': _updateLed,
    'dotstar': _updateLed,
    'pca9533': _updateLed,
    'pca9632': _updateLed,
    'manual_probe': _updateManualProbe,
    'bed_screws': _updateBedScrew,
    'heater_generic': _updateGenericHeater,
  };

  final StreamController<String> _gCodeResponseStreamController =
      StreamController.broadcast();

  bool _queriedForSession = false;

  Stream<String> get gCodeResponseStream =>
      _gCodeResponseStreamController.stream;

  Printer? _current;

  set current(Printer nI) {
    if (disposed) {
      logger.w(
          'Tried to set current Printer on an old printerService? ${identityHashCode(this)}',
          null,
          StackTrace.current);
      return;
    }
    _current = nI;
    _printerStreamCtler.add(nI);
  }

  Printer get current => _current!;

  Printer? get currentOrNull => _current;

  bool get hasCurrent => _current != null;

  Future<void> refreshPrinter() async {
    try {
      // Remove Handerls to prevent updates
      _removeJrpcHandlers();
      logger.i('Refreshing printer for uuid: $ownerUUID');
      PrinterBuilder printerBuilder = await _printerObjectsList();
      await _printerObjectsQuery(printerBuilder);
      await _temperatureStore(printerBuilder);
      // It can happen that the service disposed. Make sure to not proceed.
      if (disposed) return;
      // I need this temp variable since in some edge cases the updateSettings otherwise throws?
      var printerObj = printerBuilder.build();
      _machineService.updateMacrosInSettings(ownerUUID, printerObj.gcodeMacros);
      _registerJrpcHandlers();
      _makeSubscribeRequest(printerObj.queryableObjects);
      current = printerObj;
    } on JRpcError catch (e, s) {
      logger.e('Unable to refresh Printer $ownerUUID...', e, s);
      _showExceptionSnackbar(e, s);
      _printerStreamCtler.addError(
          MobilerakerException('Could not fetch printer...',
              parentException: e, parentStack: s),
          s);
    } catch (e, s) {
      logger.e(
          'Unexpected exception thrown during refresh $ownerUUID...', e, s);
      _showExceptionSnackbar(e, s);
      _printerStreamCtler.addError(e, s);
      if (e is Future) {
        e.then((value) => logger.e('Error was a Future: Data. $value'),
            onError: (e, s) => logger.e('Error was a Future: Error. $e', e, s));
      }
    }
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

    gCode('G91\nG1 ${moves.join(' ')} F${feedRate * 60}\nG90');
  }

  activateExtruder([int extruderIndex = 0]) {
    gCode(
        'ACTIVATE_EXTRUDER EXTRUDER=extruder${extruderIndex > 0 ? extruderIndex : ''}');
  }

  moveExtruder(double length, [double feedRate = 5]) {
    gCode('M83\nG1 E$length F${feedRate * 60}');
  }

  Future<bool> homePrintHead(Set<PrinterAxis> axis) {
    if (axis.contains(PrinterAxis.E)) {
      throw const FormatException('E axis cant be homed');
    }
    String gcode = 'G28 ';
    if (axis.length < 3) {
      gcode += axis.map(EnumToString.convertToString).join(' ');
    }
    return gCode(gcode);
  }

  Future<bool> quadGantryLevel() {
    return gCode('QUAD_GANTRY_LEVEL');
  }

  Future<bool> m84() {
    return gCode('M84');
  }

  Future<bool> zTiltAdjust() {
    return gCode('Z_TILT_ADJUST');
  }

  Future<bool> screwsTiltCalculate() {
    return gCode('SCREWS_TILT_CALCULATE');
  }

  Future<bool> probeCalibrate() {
    return gCode('PROBE_CALIBRATE');
  }

  Future<bool> zEndstopCalibrate() {
    return gCode('Z_ENDSTOP_CALIBRATE');
  }

  Future<bool> bedScrewsAdjust() {
    return gCode('BED_SCREWS_ADJUST');
  }

  Future<bool> saveConfig() {
    return gCode('SAVE_CONFIG');
  }

  m117([String? msg]) {
    gCode('M117 ${msg ?? ''}');
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

  Future<bool> gCode(String script,
      {bool throwOnError = false, bool showSnackOnErr = true}) async {
    try {
      await _jRpcClient
          .sendJRpcMethod('printer.gcode.script', params: {'script': script});
      logger.i('GCode "$script" executed successfully!');
      return true;
    } on JRpcError catch (e, s) {
      var gCodeException = GCodeException.fromJrpcError(e, parentStack: s);
      logger.i('GCode execution failed: ${gCodeException.message}');

      if (showSnackOnErr) {
        _snackBarService.show(SnackBarConfig(
            type: SnackbarType.warning,
            title: 'GCode-Error',
            message: gCodeException.message));
      }

      if (throwOnError) {
        throw gCodeException;
      }
      return false;
    }
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

  setHeaterTemperature(String heater, int target) {
    gCode('SET_HEATER_TEMPERATURE  HEATER=$heater TARGET=$target');
  }

  setTemperatureFanTarget(String fan, int target) {
    gCode('SET_TEMPERATURE_FAN_TARGET TEMPERATURE_FAN=$fan TARGET=$target');
  }

  startPrintFile(GCodeFile file) {
    _jRpcClient.sendJsonRpcWithCallback('printer.print.start',
        params: {'filename': file.pathForPrint});
  }

  resetPrintStat() {
    gCode('SDCARD_RESET_FILE');
  }

  led(String ledName, Pixel pixel) {
    gCode(
        'SET_LED LED=$ledName RED=${pixel.red.toStringAsFixed(2)} GREEN=${pixel.green.toStringAsFixed(2)} BLUE=${pixel.blue.toStringAsFixed(2)} WHITE=${pixel.white.toStringAsFixed(2)}');
  }

  Future<List<ConsoleEntry>> gcodeStore() async {
    logger.i('Fetching cached GCode commands');
    try {
      RpcResponse blockingResponse =
          await _jRpcClient.sendJRpcMethod('server.gcode_store');

      List<dynamic> raw = blockingResponse.result['gcode_store'];
      logger.i('Received cached GCode commands');
      return List.generate(
          raw.length, (index) => ConsoleEntry.fromJson(raw[index]));
    } on JRpcError catch (e) {
      logger.e('Error while fetching cached GCode commands: $e');
    }
    return List.empty();
  }

  Future<List<Command>> gcodeHelp() async {
    logger.i('Fetching available GCode commands');
    try {
      RpcResponse blockingResponse =
          await _jRpcClient.sendJRpcMethod('printer.gcode.help');
      Map<dynamic, dynamic> raw = blockingResponse.result;
      logger.i('Received ${raw.length} available GCode commands');
      return raw.entries.map((e) => Command(e.key, e.value)).toList();
    } on JRpcError catch (e) {
      logger.e('Error while fetching cached GCode commands: $e');
    }
    return List.empty();
  }

  excludeObject(ParsedObject objToExc) {
    gCode('EXCLUDE_OBJECT NAME=${objToExc.name}');
  }

  Future<void> _temperatureStore(PrinterBuilder printer) async {
    if (disposed) return;
    logger.i('Fetching cached temperature store data');

    try {
      RpcResponse blockingResponse =
      await _jRpcClient.sendJRpcMethod('server.temperature_store');

      Map<String, dynamic> raw = blockingResponse.result;
      List<String> sensors = raw.keys
          .toList(); // temperature_sensor <NAME>, extruder, heater_bed, temperature_fan <NAME>
      logger.i('Received cached temperature store for $sensors');

      raw.forEach((key, value) {
        _parseObjectType(key, raw, printer);
      });
    } on JRpcError catch (e) {
      logger.e('Error while fetching cached temperature store: $e');
    }
  }

  Future<PrinterBuilder> _printerObjectsList() async {
    // printerStream.value = Printer();
    logger.i('>>>Querying printers object list');
    RpcResponse resp = await _jRpcClient.sendJRpcMethod('printer.objects.list');

    return _parsePrinterObjectsList(resp.result);
  }

  /// Method Handler for registered in the Websocket wrapper.
  /// Handles all incoming messages and maps the correct method to it!

  _onNotifyGcodeResponse(Map<String, dynamic> rawMessage) {
    String message = rawMessage['params'][0];
    _gCodeResponseStreamController.add(message);
  }

  _onStatusUpdateHandler(Map<String, dynamic> rawMessage) {
    Map<String, dynamic> params = rawMessage['params'][0];
    if (!hasCurrent) {
      logger.w('Received statusUpdate before a printer was parsed initially!');
      return;
    }

    PrinterBuilder printerBuilder = PrinterBuilder.fromPrinter(current);

    params.forEach((key, value) {
      _parseObjectType(key, params, printerBuilder);
    });
    current = printerBuilder.build();
  }

  _parseObjectType(
      String key, Map<String, dynamic> json, PrinterBuilder printer) {
    // Splitting here the stuff e.g. for 'temperature_sensor sensor_name'
    List<String> split = key.split(' ');
    String mainObjectType = split[0];
    try {
      if (_subToPrinterObjects.containsKey(mainObjectType)) {
        var method = _subToPrinterObjects[mainObjectType];
        if (method != null) {
          if (split.length > 1) {
            method(key, json[key], printer: printer);
          } else {
            method(json[key], printer: printer);
          }
        }
      } else if (mainObjectType.startsWith('extruder')) {
        // Note that extruder will be handled above!
        _updateExtruder(json[key],
            printer: printer,
            num: int.tryParse(mainObjectType.substring(8)) ?? 0);
      }
    } catch (e, s) {
      logger.e('Error while parsing $key object', e, s);
      _printerStreamCtler.addError(e, s);
      _showParsingExceptionSnackbar(e, s, key, json);
    }
  }

  _parsePrinterObjectsList(Map<String, dynamic> result) {
    logger.i('<<<Received printer objects list!');
    logger.v(
        'PrinterObjList: ${const JsonEncoder.withIndent('  ').convert(result)}');
    PrinterBuilder printerBuilder = PrinterBuilder();

    List<String> objects = result['objects'].cast<String>();
    List<String> qObjects = [];
    List<String> gCodeMacros = [];
    int extruderCnt = 0;

    for (String objectName in objects) {
      qObjects.add(objectName);

      if (objectName.startsWith('gcode_macro ')) {
        String macro = objectName.substring(12);
        if (!skipGCodes.contains(macro)) gCodeMacros.add(macro);
      } else if (objectName.startsWith('extruder')) {
        int extNum = int.tryParse(objectName.substring(8)) ?? 0;
        extruderCnt = max(extNum + 1, extruderCnt);
      } else if (objectName.startsWith('heater_fan ')) {
        printerBuilder.fans[objectName] =
            HeaterFan(name: objectName.substring(11));
      } else if (objectName.startsWith('controller_fan ')) {
        printerBuilder.fans[objectName] =
            ControllerFan(name: objectName.substring(15));
      } else if (objectName.startsWith('temperature_fan ')) {
        printerBuilder.fans[objectName] = TemperatureFan(
          name: objectName.substring(16),
          lastHistory: DateTime(1990),
        );
      } else if (objectName.startsWith('fan_generic ')) {
        printerBuilder.fans[objectName] =
            GenericFan(name: objectName.substring(12));
      } else if (objectName.startsWith('output_pin ')) {
        printerBuilder.outputPins[objectName] =
            OutputPin(name: objectName.substring(11));
      } else if (objectName.startsWith('temperature_sensor ')) {
        printerBuilder.temperatureSensors[objectName] = TemperatureSensor(
          name: objectName.substring(19),
          lastHistory: DateTime(1990),
        );
      } else if (objectName.startsWith('led ')) {
        printerBuilder.leds[objectName] =
            DumbLed(name: objectName.substring(4));
      } else if (objectName.startsWith('pca9533 ')) {
        printerBuilder.leds[objectName] =
            DumbLed(name: objectName.substring(8));
      } else if (objectName.startsWith('pca9632 ')) {
        printerBuilder.leds[objectName] =
            DumbLed(name: objectName.substring(8));
      } else if (objectName.startsWith('neopixel ')) {
        printerBuilder.leds[objectName] =
            AddressableLed(name: objectName.substring(9));
      } else if (objectName.startsWith('dotstar ')) {
        printerBuilder.leds[objectName] =
            AddressableLed(name: objectName.substring(8));
      } else if (objectName.startsWith('heater_generic ')) {
        printerBuilder.genericHeaters[objectName] = GenericHeater(
          name: objectName.substring(15),
          lastHistory: DateTime(1990),
        );
      }
    }
    printerBuilder.extruders = List.generate(extruderCnt,
        (index) => Extruder(num: index, lastHistory: DateTime(1990)),
        growable: false);
    printerBuilder.queryableObjects = List.unmodifiable(qObjects);
    printerBuilder.gcodeMacros = List.unmodifiable(gCodeMacros);

    return printerBuilder;
  }

  _parseQueriedObjects(dynamic response, PrinterBuilder printer) async {
    logger.i('<<<Received queried printer objects');
    logger.v(
        'PrinterObjectsQuery: ${const JsonEncoder.withIndent('  ').convert(response)}');
    Map<String, dynamic> data = response['status'];

    data.forEach((key, value) {
      _parseObjectType(key, data, printer);
    });
  }

  _updatePrintFan(Map<String, dynamic> jsonResponse,
      {required PrinterBuilder printer}) {
    printer.printFan = PrintFan.partialUpdate(printer.printFan, jsonResponse);
  }

  _updateHeaterFan(String fanName, Map<String, dynamic> fanJson,
      {required PrinterBuilder printer}) {
    final HeaterFan curFan = printer.fans[fanName]! as HeaterFan;
    printer.fans = {
      ...printer.fans,
      fanName: HeaterFan.partialUpdate(curFan, fanJson)
    };
  }

  _updateControllerFan(String fanName, Map<String, dynamic> fanJson,
      {required PrinterBuilder printer}) {
    final ControllerFan curFan = printer.fans[fanName]! as ControllerFan;

    printer.fans = {
      ...printer.fans,
      fanName: ControllerFan.partialUpdate(curFan, fanJson)
    };
  }

  _updateTemperatureFan(String fanName, Map<String, dynamic> fanJson,
      {required PrinterBuilder printer}) {
    final TemperatureFan curFan = printer.fans[fanName]! as TemperatureFan;

    //TODO add TempHistory
    printer.fans = {
      ...printer.fans,
      fanName: TemperatureFan.partialUpdate(curFan, fanJson)
    };
  }

  _updateGenericFan(String fanName, Map<String, dynamic> fanJson,
      {required PrinterBuilder printer}) {
    final GenericFan curFan = printer.fans[fanName]! as GenericFan;

    printer.fans = {
      ...printer.fans,
      fanName: GenericFan.partialUpdate(curFan, fanJson)
    };
  }

  _updateTemperatureSensor(String configName, Map<String, dynamic> sensorJson,
      {required PrinterBuilder printer}) {
    TemperatureSensor current = printer.temperatureSensors[configName]!;

    printer.temperatureSensors = {
      ...printer.temperatureSensors,
      configName: TemperatureSensor.partialUpdate(current, sensorJson)
    };
  }

  _updateOutputPin(String pin, Map<String, dynamic> pinJson,
      {required PrinterBuilder printer}) {
    OutputPin curPin = printer.outputPins[pin]!;

    printer.outputPins = {
      ...printer.outputPins,
      pin: OutputPin.partialUpdate(curPin, pinJson)
    };
  }

  _updateGCodeMove(Map<String, dynamic> jsonResponse,
      {required PrinterBuilder printer}) {
    printer.gCodeMove =
        GCodeMove.partialUpdate(printer.gCodeMove, jsonResponse);
  }

  _updateMotionReport(Map<String, dynamic> jsonResponse,
      {required PrinterBuilder printer}) {
    printer.motionReport =
        MotionReport.partialUpdate(printer.motionReport, jsonResponse);
  }

  _updateDisplayStatus(Map<String, dynamic> jsonResponse,
      {required PrinterBuilder printer}) {
    printer.displayStatus = DisplayStatus.partialUpdate(
      printer.displayStatus,
      jsonResponse,
    );
  }

  _updateVirtualSd(Map<String, dynamic> jsonResponse,
      {required PrinterBuilder printer}) {
    printer.virtualSdCard =
        VirtualSdCard.partialUpdate(printer.virtualSdCard, jsonResponse);
  }

  _updatePrintStat(Map<String, dynamic> jsonResponse,
      {required PrinterBuilder printer}) {
    if (jsonResponse.containsKey('message')) {
      _onMessage(jsonResponse['message']!);
    }

    printer.print = PrintStats.partialUpdate(printer.print, jsonResponse);
  }

  _updateConfigFile(Map<String, dynamic> jsonResponse,
      {required PrinterBuilder printer}) {
    var config = printer.configFile ?? ConfigFile();
    if (jsonResponse.containsKey('settings')) {
      config = ConfigFile.parse(jsonResponse['settings']);
    }
    if (jsonResponse.containsKey('save_config_pending')) {
      config.saveConfigPending = jsonResponse['save_config_pending'];
    }
    printer.configFile = config;
  }

  _updateHeaterBed(Map<String, dynamic> jsonResponse,
      {required PrinterBuilder printer}) {
    printer.heaterBed =
        HeaterBed.partialUpdate(printer.heaterBed, jsonResponse);
  }

  _updateGenericHeater(String configName, Map<String, dynamic> jsonResponse,
      {required PrinterBuilder printer}) {
    printer.genericHeaters = {
      ...printer.genericHeaters,
      configName: GenericHeater.partialUpdate(
          printer.genericHeaters[configName]!, jsonResponse)
    };
  }

  _updateExtruder(Map<String, dynamic> jsonResponse,
      {required PrinterBuilder printer, int num = 0}) {
    List<Extruder> extruders = printer.extruders;
    Extruder extruder = printer.extruders[num];

    Extruder newExtruder = Extruder.partialUpdate(extruder, jsonResponse);

    printer.extruders = extruders
        .mapIndex((e, i) => i == num ? newExtruder : e)
        .toList(growable: false);
  }

  _updateToolhead(Map<String, dynamic> jsonResponse,
      {required PrinterBuilder printer}) {
    printer.toolhead = Toolhead.partialUpdate(printer.toolhead, jsonResponse);
  }

  _updateExcludeObject(Map<String, dynamic> jsonResponse,
      {required PrinterBuilder printer}) {
    printer.excludeObject =
        ExcludeObject.partialUpdate(printer.excludeObject, jsonResponse);
  }

  _updateLed(String led, Map<String, dynamic> jsonResponse,
      {required PrinterBuilder printer}) {
    printer.leds = {
      ...printer.leds,
      led: Led.partialUpdate(printer.leds[led]!, jsonResponse)
    };
  }

  _updateManualProbe(Map<String, dynamic> jsonResponse,
      {required PrinterBuilder printer}) {
    printer.manualProbe =
        ManualProbe.partialUpdate(printer.manualProbe, jsonResponse);
  }

  _updateBedScrew(Map<String, dynamic> jsonResponse,
      {required PrinterBuilder printer}) {
    printer.bedScrew = BedScrew.partialUpdate(printer.bedScrew, jsonResponse);
  }

  Map<String, List<String>?> _queryPrinterObjectJson(
      List<String> queryableObjects) {
    Map<String, List<String>?> queryObjects = {};
    for (String ele in queryableObjects) {
      // Splitting here the stuff e.g. for 'temperature_sensor sensor_name'
      List<String> split = ele.split(' ');
      String objTypeKey = split[0];

      if (_subToPrinterObjects.keys.contains(objTypeKey)) {
        queryObjects[ele] = null;
      } else if (ele.startsWith('extruder')) {
        queryObjects[ele] = null;
      }
    }
    return queryObjects;
  }

  /// Query the state of queryable printer objects once!
  _printerObjectsQuery(PrinterBuilder printer) async {
    if (disposed) return;
    logger.i('>>>Querying Printer Objects!');
    Map<String, List<String>?> queryObjects =
    _queryPrinterObjectJson(printer.queryableObjects);

    RpcResponse jRpcResponse = await _jRpcClient.sendJRpcMethod(
        'printer.objects.query',
        params: {'objects': queryObjects});

    _parseQueriedObjects(jRpcResponse.result, printer);
  }

  _removeJrpcHandlers() {
    _jRpcClient.removeMethodListener(
        _onStatusUpdateHandler, 'notify_status_update');

    _jRpcClient.removeMethodListener(
        _onNotifyGcodeResponse, 'notify_gcode_response');
  }

  _registerJrpcHandlers() {
    _jRpcClient.addMethodListener(
        _onStatusUpdateHandler, 'notify_status_update');

    _jRpcClient.addMethodListener(
        _onNotifyGcodeResponse, 'notify_gcode_response');
  }

  /// This method registeres every printer object for websocket updates!
  _makeSubscribeRequest(List<String> queryableObjects) {
    logger.i('Subscribing printer objects for ws-updates!');
    Map<String, List<String>?> queryObjects =
        _queryPrinterObjectJson(queryableObjects);

    _jRpcClient.sendJsonRpcWithCallback('printer.objects.subscribe',
        params: {'objects': queryObjects});
  }

  String _gcodeMoveCode(String axis, double value) {
    return '$axis${value <= 0 ? '' : '+'}${value.toStringAsFixed(2)}';
  }

  _onMessage(String message) {
    if (message.isEmpty) return;
    _snackBarService.show(SnackBarConfig(
        type: SnackbarType.warning, title: 'Klippy-Message', message: message));
  }

  void _showExceptionSnackbar(Object e, StackTrace s) {
    _snackBarService.show(SnackBarConfig.stacktraceDialog(
      dialogService: _dialogService,
      exception: e,
      stack: s,
      snackTitle: 'Refresh Printer Error',
      snackMessage: 'Could not parse: $e',
    ));
  }

  void _showParsingExceptionSnackbar(
      Object e, StackTrace s, String key, Map<String, dynamic> json) {
    _snackBarService.show(SnackBarConfig(
        type: SnackbarType.error,
        title: 'Refreshing Printer failed',
        message: 'Parsing of $key failed:\n$e',
        duration: const Duration(seconds: 30),
        mainButtonTitle: 'Details',
        closeOnMainButtonTapped: true,
        onMainButtonTapped: () {
          _dialogService.show(DialogRequest(
              type: DialogType.stacktrace,
              title: 'Parsing "${key.titleCase()}" failed',
              body:
                  '$Exception:\n $e\n\n$s\n\nFailed-Key: $key \nRaw Json:\n${jsonEncode(json)}'));
        }));
  }

  dispose() {
    _removeJrpcHandlers();

    _printerStreamCtler.close();
    _gCodeResponseStreamController.close();
  }
}
