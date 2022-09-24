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
import 'package:mobileraker/data/dto/machine/display_status.dart';
import 'package:mobileraker/data/dto/machine/exclude_object.dart';
import 'package:mobileraker/data/dto/machine/extruder.dart';
import 'package:mobileraker/data/dto/machine/fans/controller_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/generic_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/heater_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/named_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/print_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/temperature_fan.dart';
import 'package:mobileraker/data/dto/machine/gcode_move.dart';
import 'package:mobileraker/data/dto/machine/heater_bed.dart';
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
import 'package:mobileraker/util/extensions/double_extension.dart';
import 'package:mobileraker/util/ref_extension.dart';
import 'package:stringr/stringr.dart';
import 'package:vector_math/vector_math.dart';

final Set<String> skipGCodes = {'PAUSE', 'RESUME', 'CANCEL_PRINT'};
final printerServiceProvider = Provider.autoDispose
    .family<PrinterService, String>(name: 'printerServiceProvider',
        (ref, machineUUID) {
  ref.keepAlive();
  return PrinterService(ref, machineUUID);
});

final printerProvider = StreamProvider.autoDispose.family<Printer, String>(
    name: 'printerProvider', (ref, machineUUID) async* {
  ref.keepAlive();
  yield* ref.watch(printerServiceProvider(machineUUID)).printerStream;
});

final printerServiceSelectedProvider = Provider.autoDispose<PrinterService>(
    name: 'printerServiceSelectedProvider', (ref) {
  return ref.watch(printerServiceProvider(
      ref.watch(selectedMachineProvider).valueOrNull!.uuid));
});

final printerSelectedProvider = StreamProvider.autoDispose<Printer>(
    name: 'printerSelectedProvider', (ref) async* {
  try {
    var machine = await ref.watchWhereNotNull(selectedMachineProvider);

    yield* ref.watch(printerProvider(machine.uuid).stream);
  } on StateError catch (e, s) {
    // Just catch it. It is expected that the future/where might not complete!
  }
});

class PrinterService {
  PrinterService(AutoDisposeRef ref, this._ownerUUID)
      : _jRpcClient = ref.watch(jrpcClientProvider(_ownerUUID)),
        _machineService = ref.watch(machineServiceProvider),
        _snackBarService = ref.watch(snackBarServiceProvider),
        _dialogService = ref.watch(dialogServiceProvider) {
    ref.onDispose(dispose);
    _jRpcClient.addMethodListener(
        _onStatusUpdateHandler, 'notify_status_update');

    _jRpcClient.addMethodListener(
        _onNotifyGcodeResponse, 'notify_gcode_response');

    ref.listen<AsyncValue<KlipperInstance>>(klipperProvider(_ownerUUID),
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

  final String _ownerUUID;

  final SnackBarService _snackBarService;

  final DialogService _dialogService;

  final JsonRpcClient _jRpcClient;

  final MachineService _machineService;

  final StreamController<Printer> _printerStreamCtler = StreamController();

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
    'heater_fan': _updateNamedFan<HeaterFan>,
    'controller_fan': _updateNamedFan<ControllerFan>,
    'temperature_fan': _updateNamedFan<TemperatureFan>,
    'fan_generic': _updateNamedFan<GenericFan>,
    'output_pin': _updateOutputPin,
    'temperature_sensor': _updateTemperatureSensor,
    'exclude_object': _updateExcludeObject,
  };

  final StreamController<String> _gCodeResponseStreamController =
      StreamController.broadcast();

  bool _queriedForSession = false;

  Stream<String> get gCodeResponseStream =>
      _gCodeResponseStreamController.stream;

  Printer? _current;

  set current(Printer nI) {
    _current = nI;
    _printerStreamCtler.add(nI);
  }

  Printer get current => _current!;

  Printer? get currentOrNull => _current;

  bool get hasCurrent => _current != null;

  refreshPrinter() async {
    try {
      PrinterBuilder printerBuilder = PrinterBuilder();
      await _printerObjectsList(printerBuilder);
      await _printerObjectsQuery(printerBuilder);

      await _temperatureStore(printerBuilder);
      // After initally getting all information we can get the data!
      Printer printer = printerBuilder.build();
      _makeSubscribeRequest(printer.queryableObjects);
      current = printer;

      _machineService.updateMacrosInSettings(_ownerUUID, printer.gcodeMacros);
    } on JRpcError catch (e, s) {
      logger.e('Unable to refresh Printer...', e, s);
      _showExceptionSnackbar(e, s);
      _printerStreamCtler.addError(MobilerakerException(
          'Could not fetch printer...',
          parentException: e,
          parentStack: s));
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

  homePrintHead(Set<PrinterAxis> axis) {
    if (axis.contains(PrinterAxis.E)) {
      throw const FormatException('E axis cant be homed');
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

  m117([String? msg]) {
    gCode('M117 ${msg??''}');
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

  Future<List<ConsoleEntry>> gcodeStore() async {
    logger.i('Fetching cached GCode commands');
    try {
      RpcResponse blockingResponse =
          await _jRpcClient.sendJRpcMethod('server.gcode_store');

      List<dynamic> raw = blockingResponse.response['result']['gcode_store'];
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
      Map<dynamic, dynamic> raw = blockingResponse.response['result'];
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
    logger.i('Fetching cached temperature store data');

    try {
      RpcResponse blockingResponse =
          await _jRpcClient.sendJRpcMethod('server.temperature_store');

      Map<String, dynamic> raw = blockingResponse.response['result'];
      List<String> sensors = raw.keys
          .toList(); // temperature_sensor <NAME>, extruder, heater_bed, temperature_fan
      logger.i('Received cached temperature store for $sensors');

      raw.forEach((key, value) {
        _parseObjectType(key, raw, printer);
      });
    } on JRpcError catch (e) {
      logger.e('Error while fetching cached temperature store: $e');
    }
  }

  _printerObjectsList(PrinterBuilder printer) async {
    // printerStream.value = Printer();
    logger.i('>>>Querying printers object list');
    RpcResponse resp = await _jRpcClient.sendJRpcMethod('printer.objects.list');
    _parsePrinterObjectsList(resp.response, printer);
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
      _showExceptionSnackbar(e, s);
    }
  }

  _parsePrinterObjectsList(
      Map<String, dynamic> response, PrinterBuilder printer) {
    var result = response['result'];
    logger.i('<<<Received printer objects list!');
    logger.v(
        'PrinterObjList: ${const JsonEncoder.withIndent('  ').convert(result)}');
    List<String> objects = result['objects'].cast<String>();
    List<String> qObjects = [];
    List<String> gCodeMacros = [];
    int extruderCnt = 0;
    Set<NamedFan> fans = {};
    Set<TemperatureSensor> temperatureSensors = {};
    Set<OutputPin> outputPins = {};

    for (String element in objects) {
      qObjects.add(element);

      if (element.startsWith('gcode_macro ')) {
        String macro = element.substring(12);
        if (!skipGCodes.contains(macro)) gCodeMacros.add(macro);
      } else if (element.startsWith('extruder')) {
        int extNum = int.tryParse(element.substring(8)) ?? 0;
        extruderCnt = max(extNum + 1, extruderCnt);
      } else if (element.startsWith('heater_fan ')) {
        fans.add(HeaterFan(name: element.substring(11)));
      } else if (element.startsWith('controller_fan ')) {
        fans.add(ControllerFan(name: element.substring(15)));
      } else if (element.startsWith('temperature_fan ')) {
        fans.add(TemperatureFan(name: element.substring(16)));
      } else if (element.startsWith('fan_generic ')) {
        fans.add(GenericFan(name: element.substring(12)));
      } else if (element.startsWith('output_pin ')) {
        outputPins.add(OutputPin(name: element.substring(11)));
      } else if (element.startsWith('temperature_sensor ')) {
        temperatureSensors.add(TemperatureSensor(
            name: element.substring(19), lastHistory: DateTime(1990)));
      }
    }
    printer.fans = List.unmodifiable(fans);
    printer.temperatureSensors = List.unmodifiable(temperatureSensors);
    printer.outputPins = List.unmodifiable(outputPins);
    printer.extruders = List.generate(extruderCnt,
        (index) => Extruder(num: index, lastHistory: DateTime(1990)),
        growable: false);
    printer.queryableObjects = List.unmodifiable(qObjects);
    printer.gcodeMacros = List.unmodifiable(gCodeMacros);
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

  _updatePrintFan(Map<String, dynamic> fanJson,
      {required PrinterBuilder printer}) {
    if (fanJson.containsKey('speed')) {
      double speed = fanJson['speed'];
      if (printer.printFan == null) {
        printer.printFan = PrintFan(speed: speed);
      } else {
        printer.printFan = printer.printFan!.copyWith(speed: speed);
      }
    }
  }

  _updateNamedFan<T extends NamedFan>(
      String fanName, Map<String, dynamic> fanJson,
      {required PrinterBuilder printer}) {
    List<String> split = fanName.split(' ');
    String hName = split.length > 1 ? split.skip(1).join(' ') : split[0];

    if (!fanJson.containsKey('speed')) {
      return;
    }

    printer.fans = printer.fans.map((e) {
      if (e is T && e.name == hName) {
        return e.copyWith(speed: fanJson['speed']);
      }
      return e;
    }).toList(growable: false);
  }

  _updateTemperatureSensor(String sensor, Map<String, dynamic> sensorJson,
      {required PrinterBuilder printer}) {
    List<String> split = sensor.split(' ');
    String sName = split.length > 1 ? split.skip(1).join(' ') : split[0];

    printer.temperatureSensors = printer.temperatureSensors.map((e) {
      if (e.name != sName) {
        return e;
      }

      String? name;
      double? temperature;
      double? measuredMinTemp;
      double? measuredMaxTemp;
      DateTime? lastHistory;
      List<double>? temperatureHistory;

      if (sensorJson.containsKey('temperature')) {
        temperature = sensorJson['temperature'];
      }
      if (sensorJson.containsKey('measured_min_temp')) {
        measuredMinTemp = sensorJson['measured_min_temp'];
      }
      if (sensorJson.containsKey('measured_max_temp')) {
        measuredMaxTemp = sensorJson['measured_max_temp'];
      }

      // Update temp cache for graphs!
      DateTime now = DateTime.now();
      if (now.difference(e.lastHistory).inSeconds >= 1) {
        temperatureHistory = _updateHistoryList(
            e.temperatureHistory, temperature ?? e.temperature);
        lastHistory = now;
      }

      // Ill just put the tempCache here because I am lazy.. kinda sucks but who cares
      if (sensorJson.containsKey('temperatures')) {
        temperatureHistory =
            (sensorJson['temperatures'] as List<dynamic>).cast<double>();
      }

      return e.copyWith(
        name: name ?? e.name,
        temperature: temperature ?? e.temperature,
        measuredMinTemp: measuredMinTemp ?? e.measuredMinTemp,
        measuredMaxTemp: measuredMaxTemp ?? e.measuredMaxTemp,
        lastHistory: lastHistory ?? e.lastHistory,
        temperatureHistory: temperatureHistory ?? e.temperatureHistory,
      );
    }).toList(growable: false);
  }

  _updateOutputPin(String pin, Map<String, dynamic> pinJson,
      {required PrinterBuilder printer}) {
    List<String> split = pin.split(' ');
    String sName = split.length > 1 ? split.skip(1).join(' ') : split[0];
    if (!pinJson.containsKey('value')) {
      return;
    }

    printer.outputPins = printer.outputPins.map((e) {
      if (e.name == sName) {
        return e.copyWith(value: pinJson['value']);
      }
      return e;
    }).toList(growable: false);
  }

  _updateGCodeMove(Map<String, dynamic> gCodeJson,
      {required PrinterBuilder printer}) {
    double? speedFactor;
    double? speed;
    double? extrudeFactor;
    bool? absoluteCoordinates;
    bool? absoluteExtrude;
    List<double>? position;
    List<double>? homingOrigin;
    List<double>? gcodePosition;

    if (gCodeJson.containsKey('speed_factor')) {
      speedFactor = (gCodeJson['speed_factor'] as double).toPrecision(2);
    }
    if (gCodeJson.containsKey('speed')) {
      speed = gCodeJson['speed'];
    }
    if (gCodeJson.containsKey('extrude_factor')) {
      extrudeFactor = _toPrecision(gCodeJson['extrude_factor']);
    }
    if (gCodeJson.containsKey('absolute_coordinates')) {
      absoluteCoordinates = gCodeJson['absolute_coordinates'];
    }
    if (gCodeJson.containsKey('absolute_extrude')) {
      absoluteExtrude = gCodeJson['absolute_extrude'];
    }

    if (gCodeJson.containsKey('position')) {
      position = gCodeJson['position'].cast<double>();
    }
    if (gCodeJson.containsKey('homing_origin')) {
      homingOrigin = gCodeJson['homing_origin'].cast<double>();
    }
    if (gCodeJson.containsKey('gcode_position')) {
      gcodePosition = gCodeJson['gcode_position'].cast<double>();
    }

    GCodeMove old = printer.gCodeMove ?? const GCodeMove();

    printer.gCodeMove = GCodeMove(
      speedFactor: speedFactor ?? old.speedFactor,
      speed: speed ?? old.speed,
      extrudeFactor: extrudeFactor ?? old.extrudeFactor,
      absoluteCoordinates: absoluteCoordinates ?? old.absoluteCoordinates,
      absoluteExtrude: absoluteExtrude ?? old.absoluteExtrude,
      position: position ?? old.position,
      homingOrigin: homingOrigin ?? old.homingOrigin,
      gcodePosition: gcodePosition ?? old.gcodePosition,
    );
  }

  _updateMotionReport(Map<String, dynamic> gCodeJson,
      {required PrinterBuilder printer}) {
    List<double>? position;
    double? liveVelocity;
    double? liveExtruderVelocity;

    if (gCodeJson.containsKey('live_position')) {
      position = gCodeJson['live_position'].cast<double>();
    }
    if (gCodeJson.containsKey('live_velocity')) {
      liveVelocity = gCodeJson['live_velocity'];
    }
    if (gCodeJson.containsKey('live_extruder_velocity')) {
      liveExtruderVelocity = gCodeJson['live_extruder_velocity'];
    }

    MotionReport old = printer.motionReport ?? const MotionReport();

    printer.motionReport = MotionReport(
      livePosition: position ?? old.livePosition,
      liveExtruderVelocity: liveExtruderVelocity ?? old.liveExtruderVelocity,
      liveVelocity: liveVelocity ?? old.liveVelocity,
    );
  }

  _updateDisplayStatus(Map<String, dynamic> json,
      {required PrinterBuilder printer}) {
    double? progress = json['progress'];
    String? message = json['message'];

    DisplayStatus old = printer.displayStatus ?? const DisplayStatus();

    printer.displayStatus = DisplayStatus(
      progress: progress ?? old.progress,
      message: message,
    );
  }

  _updateVirtualSd(Map<String, dynamic> virtualSDJson,
      {required PrinterBuilder printer}) {
    double? progress;
    bool? isActive;
    int? filePosition;

    if (virtualSDJson.containsKey('progress')) {
      progress = virtualSDJson['progress'];
    }
    if (virtualSDJson.containsKey('is_active')) {
      isActive = virtualSDJson['is_active'];
    }
    if (virtualSDJson.containsKey('file_position')) {
      filePosition =
          int.tryParse(virtualSDJson['file_position'].toString()) ?? 0;
    }
    VirtualSdCard old = printer.virtualSdCard ?? const VirtualSdCard();
    printer.virtualSdCard = old.copyWith(
        progress: progress ?? old.progress,
        isActive: isActive ?? old.isActive,
        filePosition: filePosition ?? old.filePosition);
  }

  _updatePrintStat(Map<String, dynamic> printStatJson,
      {required PrinterBuilder printer}) {
    PrintState? state;
    double? totalDuration;
    double? printDuration;
    double? filamentUsed;
    String? message;
    String? filename;

    if (printStatJson.containsKey('state')) {
      state =
          EnumToString.fromString(PrintState.values, printStatJson['state'])!;
    }
    if (printStatJson.containsKey('filename')) {
      filename = printStatJson['filename'];
    }
    if (printStatJson.containsKey('total_duration')) {
      totalDuration = printStatJson['total_duration'];
    }
    if (printStatJson.containsKey('print_duration')) {
      printDuration = printStatJson['print_duration'];
    }
    if (printStatJson.containsKey('filament_used')) {
      filamentUsed = printStatJson['filament_used'];
    }
    if (printStatJson.containsKey('message')) {
      message = printStatJson['message'];
      _onMessage(message!);
    }
    PrintStats old = printer.print ?? const PrintStats();

    printer.print = PrintStats(
      state: state ?? old.state,
      totalDuration: totalDuration ?? old.totalDuration,
      printDuration: printDuration ?? old.printDuration,
      filamentUsed: filamentUsed ?? old.filamentUsed,
      message: message ?? old.message,
      filename: filename ?? old.filename,
    );
  }

  _updateConfigFile(Map<String, dynamic> printStatJson,
      {required PrinterBuilder printer}) {
    var config = printer.configFile ?? ConfigFile();
    if (printStatJson.containsKey('settings')) {
      config = ConfigFile.parse(printStatJson['settings']);
    }
    if (printStatJson.containsKey('save_config_pending')) {
      config.saveConfigPending = printStatJson['save_config_pending'];
    }
    printer.configFile = config;
  }

  _updateHeaterBed(Map<String, dynamic> heatedBedJson,
      {required PrinterBuilder printer}) {
    HeaterBed old = printer.heaterBed ?? HeaterBed(lastHistory: DateTime(1990));

    double? temperature;
    double? target;
    double? power;
    List<double>? temperatureHistory;
    List<double>? targetHistory;
    List<double>? powerHistory;
    DateTime? lastHistory;

    if (heatedBedJson.containsKey('temperature')) {
      temperature = heatedBedJson['temperature'];
    }
    if (heatedBedJson.containsKey('target')) {
      target = heatedBedJson['target'];
    }
    if (heatedBedJson.containsKey('power')) {
      power = heatedBedJson['power'];
    }

    // Update temp cache for graphs!
    DateTime now = DateTime.now();
    if (now.difference(old.lastHistory).inSeconds >= 1) {
      temperatureHistory = _updateHistoryList(
          old.temperatureHistory, temperature ?? old.temperature);
      targetHistory =
          _updateHistoryList(old.targetHistory, target ?? old.target);
      powerHistory = _updateHistoryList(old.powerHistory, power ?? old.target);
      lastHistory = now;
    }

    // Ill just put the tempCache here because I am lazy.. kinda sucks but who cares
    if (heatedBedJson.containsKey('temperatures')) {
      temperatureHistory =
          (heatedBedJson['temperatures'] as List<dynamic>).cast<double>();
    }
    if (heatedBedJson.containsKey('targets')) {
      targetHistory =
          (heatedBedJson['targets'] as List<dynamic>).cast<double>();
    }
    if (heatedBedJson.containsKey('powers')) {
      powerHistory = (heatedBedJson['powers'] as List<dynamic>).cast<double>();
    }

    printer.heaterBed = HeaterBed(
      temperature: temperature ?? old.temperature,
      target: target ?? old.target,
      power: power ?? old.power,
      temperatureHistory: temperatureHistory ?? old.temperatureHistory,
      targetHistory: targetHistory ?? old.targetHistory,
      powerHistory: powerHistory ?? old.powerHistory,
      lastHistory: lastHistory ?? old.lastHistory,
    );
  }

  _updateExtruder(Map<String, dynamic> extruderJson,
      {required PrinterBuilder printer, int num = 0}) {
    List<Extruder> extruders = printer.extruders;

    Extruder extruder = printer.extruders[num];
    double? temperature;
    double? target;
    double? pressureAdvance;
    double? smoothTime;
    double? power;
    List<double>? temperatureHistory;
    List<double>? targetHistory;
    List<double>? powerHistory;
    DateTime? lastHistory;
    if (extruderJson.containsKey('temperature')) {
      temperature = extruderJson['temperature'];
    }
    if (extruderJson.containsKey('target')) {
      target = extruderJson['target'];
    }
    if (extruderJson.containsKey('pressure_advance')) {
      pressureAdvance = extruderJson['pressure_advance'];
    }
    if (extruderJson.containsKey('smooth_time')) {
      smoothTime = extruderJson['smooth_time'];
    }
    if (extruderJson.containsKey('power')) {
      power = extruderJson['power'];
    }

    // Update temp cache for graphs!
    DateTime now = DateTime.now();
    if (now.difference(extruder.lastHistory).inSeconds >= 1) {
      temperatureHistory = _updateHistoryList(
          extruder.temperatureHistory, temperature ?? extruder.temperature);
      targetHistory =
          _updateHistoryList(extruder.targetHistory, target ?? extruder.target);
      powerHistory =
          _updateHistoryList(extruder.powerHistory, power ?? extruder.power);
      lastHistory = now;
    }

    // Ill just put the tempCache here because I am lazy.. kinda sucks but who cares
    if (extruderJson.containsKey('temperatures')) {
      temperatureHistory =
          (extruderJson['temperatures'] as List<dynamic>).cast<double>();
    }
    if (extruderJson.containsKey('targets')) {
      targetHistory = (extruderJson['targets'] as List<dynamic>).cast<double>();
    }
    if (extruderJson.containsKey('powers')) {
      powerHistory = (extruderJson['powers'] as List<dynamic>).cast<double>();
    }
    var newExtruder = extruder.copyWith(
        temperature: temperature ?? extruder.temperature,
        target: target ?? extruder.target,
        pressureAdvance: pressureAdvance ?? extruder.pressureAdvance,
        smoothTime: smoothTime ?? extruder.smoothTime,
        power: power ?? extruder.power,
        temperatureHistory: temperatureHistory ?? extruder.temperatureHistory,
        targetHistory: targetHistory ?? extruder.targetHistory,
        powerHistory: powerHistory ?? extruder.powerHistory,
        lastHistory: lastHistory ?? extruder.lastHistory);

    printer.extruders = extruders
        .mapIndex((e, i) => i == num ? newExtruder : e)
        .toList(growable: false);
  }

  _updateToolhead(Map<String, dynamic> toolHeadJson,
      {required PrinterBuilder printer}) {
    Toolhead toolhead = printer.toolhead ?? const Toolhead();

    Set<PrinterAxis> homedAxes = toolhead.homedAxes;
    List<double> position = toolhead.position;
    double? printTime = toolhead.printTime;
    double? estimatedPrintTime = toolhead.estimatedPrintTime;
    double maxVelocity = toolhead.maxVelocity;
    double maxAccel = toolhead.maxAccel;
    double maxAccelToDecel = toolhead.maxAccelToDecel;
    String activeExtruder = toolhead.activeExtruder;
    double squareCornerVelocity = toolhead.squareCornerVelocity;

    if (toolHeadJson.containsKey('homed_axes')) {
      String hAxes = toolHeadJson['homed_axes'];
      homedAxes = hAxes
          .toUpperCase()
          .split('')
          .map((e) => EnumToString.fromString(PrinterAxis.values, e)!)
          .toSet();
    }
    if (toolHeadJson.containsKey('position')) {
      position = toolHeadJson['position'].cast<double>();
    }
    if (toolHeadJson.containsKey('print_time')) {
      printTime = toolHeadJson['print_time'];
    }
    if (toolHeadJson.containsKey('max_velocity')) {
      maxVelocity = toolHeadJson['max_velocity'];
    }
    if (toolHeadJson.containsKey('max_accel')) {
      maxAccel = toolHeadJson['max_accel'];
    }
    if (toolHeadJson.containsKey('max_accel_to_decel')) {
      maxAccelToDecel = toolHeadJson['max_accel_to_decel'];
    }
    if (toolHeadJson.containsKey('extruder')) {
      activeExtruder = toolHeadJson['extruder'];
    }
    if (toolHeadJson.containsKey('square_corner_velocity')) {
      squareCornerVelocity = toolHeadJson['square_corner_velocity'];
    }
    if (toolHeadJson.containsKey('estimated_print_time')) {
      estimatedPrintTime = toolHeadJson['estimated_print_time'];
    }

    printer.toolhead = toolhead.copyWith(
      homedAxes: homedAxes,
      position: position,
      printTime: printTime,
      estimatedPrintTime: estimatedPrintTime,
      maxVelocity: maxVelocity,
      maxAccel: maxAccel,
      maxAccelToDecel: maxAccelToDecel,
      activeExtruder: activeExtruder,
      squareCornerVelocity: squareCornerVelocity,
    );
  }

  _updateExcludeObject(Map<String, dynamic> json,
      {required PrinterBuilder printer}) {
    String? currentObject;
    List<String>? excludedObjects;
    List<ParsedObject>? objects;

    if (json.containsKey('current_object')) {
      currentObject = json['current_object'];
    }

    if (json.containsKey('excluded_objects')) {
      excludedObjects =
          (json['excluded_objects'] as List<dynamic>).cast<String>();
    }
    if (json.containsKey('objects')) {
      List<dynamic> objRaw = json['objects'];
      List<ParsedObject> prasedObjects = [];
      for (Map<String, dynamic> e in objRaw) {
        Vector2 center;
        String name = e['name'];
        List<Vector2> polygons;
        if (e.containsKey('center')) {
          List<dynamic> centerFromMsg = e['center'];
          center = centerFromMsg.isEmpty
              ? Vector2.zero()
              : Vector2.array(centerFromMsg.cast<double>());
        } else {
          center = Vector2.zero();
        }
        if (e.containsKey('polygon')) {
          List<dynamic> polys = e['polygon'];
          polygons = polys.map((e) {
            List<dynamic> list = e as List<dynamic>;
            return Vector2.array(list.cast<double>());
          }).toList(growable: false);
        } else {
          polygons = [];
        }

        prasedObjects
            .add(ParsedObject(name: name, center: center, polygons: polygons));
      }

      objects = List.unmodifiable(prasedObjects);
    }

    ExcludeObject old = printer.excludeObject ?? const ExcludeObject();
    printer.excludeObject = old.copyWith(
        currentObject: currentObject,
        excludedObjects: excludedObjects ?? old.excludedObjects,
        objects: objects ?? old.objects);
    logger.v('New exclude_printer: ${printer.excludeObject}');
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
    logger.i('>>>Querying Printer Objects!');
    Map<String, List<String>?> queryObjects =
        _queryPrinterObjectJson(printer.queryableObjects);

    RpcResponse jRpcResponse = await _jRpcClient.sendJRpcMethod(
        'printer.objects.query',
        params: {'objects': queryObjects});

    _parseQueriedObjects(jRpcResponse.response['result'], printer);
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

  double _toPrecision(double d, [int fraction = 2]) {
    return d.toPrecision(fraction);
  }

  void _showExceptionSnackbar(Object e, StackTrace s) {
    _snackBarService.show(SnackBarConfig(
        type: SnackbarType.error,
        title: 'Refresh Printer Error',
        message: 'Could not parse: $e',
        duration: const Duration(seconds: 30),
        mainButtonTitle: 'Details',
        closeOnMainButtonTapped: true,
        onMainButtonTapped: () {
          _dialogService.show(DialogRequest(
              type: DialogType.stacktrace,
              title: 'Refresh Printer Error',
              body: 'Exception:\n $e\n\n$s'));
        }));
  }

  List<T>? _updateHistoryList<T>(List<T>? currentHistory, T toAdd) {
    if (currentHistory == null) {
      return null;
    }
    if (currentHistory.length >= 1200) {
      return [...currentHistory.sublist(1), toAdd];
    }
    return [...currentHistory, toAdd];
  }

  dispose() {
    logger.e('PrinterService Dispo');
    _printerStreamCtler.close();
    _gCodeResponseStreamController.close();
  }
}
