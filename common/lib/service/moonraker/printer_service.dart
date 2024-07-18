/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/data/dto/machine/exclude_object.dart';
import 'package:common/data/dto/machine/leds/led.dart';
import 'package:common/data/dto/machine/printer.dart';
import 'package:common/data/dto/machine/printer_axis_enum.dart';
import 'package:common/exceptions/gcode_exception.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/extensions/string_extension.dart';
import 'package:common/util/extensions/uri_extension.dart';
import 'package:common/util/logger.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stringr/stringr.dart';

import '../../data/dto/console/command.dart';
import '../../data/dto/console/console_entry.dart';
import '../../data/dto/machine/printer_builder.dart';
import '../../data/dto/server/klipper.dart';
import '../../network/jrpc_client_provider.dart';
import '../selected_machine_service.dart';
import '../ui/dialog_service_interface.dart';
import '../ui/snackbar_service_interface.dart';
import 'file_service.dart';
import 'klippy_service.dart';

part 'printer_service.g.dart';

@riverpod
PrinterService printerService(PrinterServiceRef ref, String machineUUID) {
  return PrinterService(ref, machineUUID);
}

@riverpod
Stream<Printer> printer(PrinterRef ref, String machineUUID) {
  // ref.keepAlive();
  var printerService = ref.watch(printerServiceProvider(machineUUID));
  ref.listenSelf((previous, next) {
    final previousFileName = previous?.valueOrNull?.print.filename;
    final nextFileName = next.valueOrNull?.print.filename;
    // The 2nd case is to cover rare race conditions where a printer update was issued at the same time as this code was executed
    if (previousFileName != nextFileName ||
        next.hasValue &&
            (nextFileName?.isNotEmpty == true && next.value?.currentFile == null ||
                nextFileName?.isEmpty == true && next.value?.currentFile != null)) {
      printerService.updateCurrentFile(nextFileName).ignore();
    }

    final prevMessage = previous?.valueOrNull?.print.message;
    final nextMessage = next.valueOrNull?.print.message;
    if (prevMessage != nextMessage && nextMessage?.isNotEmpty == true) {
      ref.read(snackBarServiceProvider).show(SnackBarConfig(
            type: SnackbarType.warning,
            title: 'Klippy-Message',
            message: nextMessage,
          ));
    }
  });
  return printerService.printerStream;
}

@riverpod
Future<List<Command>> printerAvailableCommands(PrinterAvailableCommandsRef ref, String machineUUID) async {
  return ref.watch(printerServiceProvider(machineUUID)).gcodeHelp();
}

@riverpod
PrinterService printerServiceSelected(PrinterServiceSelectedRef ref) {
  return ref.watch(printerServiceProvider(ref.watch(selectedMachineProvider).requireValue!.uuid));
}

@riverpod
Stream<Printer> printerSelected(PrinterSelectedRef ref) async* {
  try {
    var machine = await ref.watch(selectedMachineProvider.future);
    if (machine == null) return;

    yield* ref.watchAsSubject(printerProvider(machine.uuid));
  } on StateError catch (_) {
    // Just catch it. It is expected that the future/where might not complete!
  }
}

class PrinterService {
  PrinterService(AutoDisposeRef ref, this.ownerUUID)
      : _jRpcClient = ref.watch(jrpcClientProvider(ownerUUID)),
        _fileService = ref.watch(fileServiceProvider(ownerUUID)),
        _snackBarService = ref.watch(snackBarServiceProvider),
        _dialogService = ref.watch(dialogServiceProvider) {
    ref.onDispose(dispose);

    ref.listen(klipperProvider(ownerUUID).selectAs((value) => value.klippyState), (previous, next) {
      logger.i(
          '[Printer Service ${_jRpcClient.clientType}@${_jRpcClient.uri.obfuscate()}] Received new klippyState: $previous -> $next: ${previous?.valueOrFullNull} -> ${next.valueOrFullNull}');
      switch (next.valueOrFullNull) {
        case KlipperState.ready:
          if (!_queriedForSession) {
            _queriedForSession = true;
            refreshPrinter();
          }
          break;
        default:
          _queriedForSession = false;
      }
    }, fireImmediately: true);
  }

  final String ownerUUID;

  final SnackBarService _snackBarService;

  final DialogService _dialogService;

  final JsonRpcClient _jRpcClient;

  final FileService _fileService;

  final StreamController<Printer> _printerStreamCtler = StreamController();

  bool get disposed => _printerStreamCtler.isClosed;

  Stream<Printer> get printerStream => _printerStreamCtler.stream;

  /// This map defines how different printerObjects will be parsed
  /// For multi-word printer objects (e.g. outputs, temperature_fan...) use the prefix value

  final StreamController<String> _gCodeResponseStreamController = StreamController.broadcast();

  bool _queriedForSession = false;

  //TODO: Make this private and offer a riverpod provider
  Stream<String> get gCodeResponseStream => _gCodeResponseStreamController.stream;

  Printer? _current;

  final bool _flag = false;

  set current(Printer nI) {
    if (disposed) {
      logger.w(
          'Tried to set current Printer on an old printerService? ${identityHashCode(this)}', null, StackTrace.current);
      return;
    }
    if (_flag) return;
    _current = nI;
    _printerStreamCtler.add(nI);

    // Future.delayed(Duration(seconds: 5), () {
    //   _flag = true;
    //   logger.i('Delayed log');
    //   _printerStreamCtler.addError(Exception('Delayed Error'));
    // });
  }

  Printer get current => _current!;

  Printer? get currentOrNull => _current;

  bool get hasCurrent => _current != null;

  Future<void> refreshPrinter() async {
    try {
      // await Future.delayed(Duration(seconds:15));
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
      // _machineService.updateMacrosInSettings(ownerUUID, printerObj.gcodeMacros).ignore();
      _registerJrpcHandlers();
      _makeSubscribeRequest(printerObj.queryableObjects);
      current = printerObj;
    } on JRpcError catch (e, s) {
      logger.e('Unable to refresh Printer $ownerUUID...', e, s);
      _showExceptionSnackbar(e, s);
      _printerStreamCtler.addError(
          MobilerakerException('Could not fetch printer...', parentException: e, parentStack: s), s);
      if (e is! JRpcTimeoutError) {
        FirebaseCrashlytics.instance.recordError(e, s, reason: 'JRpcError thrown during printer refresh');
      }
    } catch (e, s) {
      logger.e('Unexpected exception thrown during refresh $ownerUUID...', e, s);
      _showExceptionSnackbar(e, s);
      _printerStreamCtler.addError(e, s);
      if (e is Future) {
        e.then((value) => logger.e('Error was a Future: Data. $value'),
            onError: (e, s) => logger.e('Error was a Future: Error. $e', e, s));
      }
      FirebaseCrashlytics.instance.recordError(e, s, reason: 'Error thrown during printer refresh');
    }
  }

  resumePrint() {
    _jRpcClient.sendJRpcMethod('printer.print.resume', timeout: Duration.zero).ignore();
  }

  pausePrint() {
    _jRpcClient.sendJRpcMethod('printer.print.pause', timeout: Duration.zero).ignore();
  }

  cancelPrint() {
    _jRpcClient.sendJRpcMethod('printer.print.cancel', timeout: Duration.zero).ignore();
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

  Future<void> movePrintHead({double? x, double? y, double? z, double feedRate = 100}) {
    List<String> moves = [];
    if (x != null) moves.add(_gcodeMoveCode('X', x));
    if (y != null) moves.add(_gcodeMoveCode('Y', y));
    if (z != null) moves.add(_gcodeMoveCode('Z', z));

    return gCode('G91\nG1 ${moves.join(' ')} F${feedRate * 60}\nG90');
  }

  Future<void> activateExtruder([int extruderIndex = 0]) async {
    await gCode('ACTIVATE_EXTRUDER EXTRUDER=extruder${extruderIndex > 0 ? extruderIndex : ''}');
  }

  Future<void> moveExtruder(num length, [num velocity = 5, bool waitMove = false]) async {
    final m400 = waitMove ? '\nM400' : '';
    await gCode('M83\nG1 E$length F${velocity * 60}$m400');
  }

  Future<bool> homePrintHead(Set<PrinterAxis> axis) {
    if (axis.contains(PrinterAxis.E)) {
      throw const FormatException('E axis cant be homed');
    }
    String gcode = 'G28 ';
    if (axis.length < 3) {
      gcode += axis.map((e) => e.name).join(' ');
    }
    return gCode(gcode);
  }

  Future<bool> quadGantryLevel() {
    return gCode('QUAD_GANTRY_LEVEL');
  }

  Future<bool> m84() {
    return gCode('M84');
  }

  Future<bool> bedMeshLevel() {
    return gCode('BED_MESH_CALIBRATE');
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

  Future<bool> m117([String? msg]) {
    return gCode('M117 ${msg ?? ''}');
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

  Future<void> filamentSensor(String sensorName, bool enable) async {
    // SET_FILAMENT_SENSOR SENSOR=<sensor_name> ENABLE=[0|1]
    await gCode('SET_FILAMENT_SENSOR SENSOR=$sensorName ENABLE=${enable ? 1 : 0}');
  }

  Future<bool> gCode(String script, {bool throwOnError = false, bool showSnackOnErr = true}) async {
    try {
      await _jRpcClient.sendJRpcMethod('printer.gcode.script', params: {'script': script}, timeout: Duration.zero);
      logger.i('GCode "$script" executed successfully!');
      return true;
    } on JRpcError catch (e, s) {
      var gCodeException = GCodeException.fromJrpcError(e, parentStack: s);
      logger.i('GCode execution failed: ${gCodeException.message}');

      if (showSnackOnErr) {
        _snackBarService
            .show(SnackBarConfig(type: SnackbarType.warning, title: 'GCode-Error', message: gCodeException.message));
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
    _jRpcClient.sendJRpcMethod('printer.print.start', params: {'filename': file.pathForPrint}).ignore();
  }

  resetPrintStat() {
    gCode('SDCARD_RESET_FILE');
  }

  reprintCurrentFile() {
    var lastPrinted = _current?.print.filename;
    if (lastPrinted?.isNotEmpty == true) {
      _jRpcClient.sendJRpcMethod('printer.print.start', params: {'filename': lastPrinted}).ignore();
    }
  }

  led(String ledName, Pixel pixel) {
    gCode(
        'SET_LED LED=$ledName RED=${pixel.red.toStringAsFixed(2)} GREEN=${pixel.green.toStringAsFixed(2)} BLUE=${pixel.blue.toStringAsFixed(2)} WHITE=${pixel.white.toStringAsFixed(2)}');
  }

  Future<List<ConsoleEntry>> gcodeStore() async {
    logger.i('Fetching cached GCode commands');
    try {
      RpcResponse blockingResponse = await _jRpcClient.sendJRpcMethod('server.gcode_store');

      List<dynamic> raw = blockingResponse.result['gcode_store'];
      logger.i('Received cached GCode commands');
      return List.generate(raw.length, (index) => ConsoleEntry.fromJson(raw[index]));
    } on JRpcError catch (e) {
      logger.e('Error while fetching cached GCode commands: $e');
    }
    return List.empty();
  }

  Future<List<Command>> gcodeHelp() async {
    logger.i('Fetching available GCode commands');
    try {
      RpcResponse blockingResponse = await _jRpcClient.sendJRpcMethod('printer.gcode.help');
      Map<dynamic, dynamic> raw = blockingResponse.result;
      logger.i('Received ${raw.length} available GCode commands');
      return raw.entries.map((e) => Command(e.key, e.value)).toList();
    } on JRpcError catch (e) {
      logger.e('Error while fetching cached GCode commands: $e');
    }
    return List.empty();
  }

  void excludeObject(ParsedObject objToExc) {
    gCode('EXCLUDE_OBJECT NAME=${objToExc.name}');
  }

  Future<void> updateCurrentFile(String? file) async {
    logger.i('Also requesting an update for current_file: $file');

    try {
      var gCodeMeta = (file?.isNotEmpty == true) ? await _fileService.getGCodeMetadata(file!) : null;

      if (hasCurrent) {
        logger.i('UPDATED current_file: $gCodeMeta');
        current = current.copyWith(currentFile: gCodeMeta);
      }
    } catch (e, s) {
      logger.e('Error while updating current_file', e, s);
      current = current.copyWith(currentFile: null);
    }
  }

  firmwareRetraction({
    double? retractLength,
    double? retractSpeed,
    double? unretractExtraLength,
    double? unretractSpeed,
  }) {
    // SET_RETRACTION [RETRACT_LENGTH=<mm>] [RETRACT_SPEED=<mm/s>] [UNRETRACT_EXTRA_LENGTH=<mm>] [UNRETRACT_SPEED=<mm/s>]
    List<String> args = [];
    if (retractLength != null) args.add('RETRACT_LENGTH=$retractLength');
    if (retractSpeed != null) args.add('RETRACT_SPEED=$retractSpeed');
    if (unretractExtraLength != null) args.add('UNRETRACT_EXTRA_LENGTH=$unretractExtraLength');
    if (unretractSpeed != null) args.add('UNRETRACT_SPEED=$unretractSpeed');
    if (args.isNotEmpty) {
      gCode('SET_RETRACTION ${args.join(' ')}');
    }
  }

  Future<void> loadBedMeshProfile(String profileName) async {
    assert(profileName.isNotEmpty);
    // BED_MESH_PROFILE LOAD="VW-Plate(Probe)"
    await gCode('BED_MESH_PROFILE LOAD="$profileName"');
  }

  Future<void> clearBedMeshProfile() async {
    await gCode('BED_MESH_CLEAR');
  }

  Future<void> _temperatureStore(PrinterBuilder printer) async {
    if (disposed) return;
    logger.i('Fetching cached temperature store data');

    try {
      RpcResponse blockingResponse = await _jRpcClient.sendJRpcMethod('server.temperature_store');

      Map<String, dynamic> raw = blockingResponse.result;
      List<String> sensors =
          raw.keys.toList(); // temperature_sensor <NAME>, extruder, heater_bed, temperature_fan <NAME>
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
    final result = resp.result;

    logger.i('<<<Received printer objects list!');
    logger.v('PrinterObjList: ${const JsonEncoder.withIndent('  ').convert(result)}');

    return PrinterBuilder()..queryableObjects = List.unmodifiable(result['objects'].cast<String>());
  }

  /// Method Handler for registered in the Websocket wrapper.
  /// Handles all incoming messages and maps the correct method to it!

  void _onNotifyGcodeResponse(Map<String, dynamic> rawMessage) {
    String message = rawMessage['params'][0];
    _gCodeResponseStreamController.add(message);
  }

  void _onStatusUpdateHandler(Map<String, dynamic> rawMessage) {
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

  void _parseObjectType(String key, Map<String, dynamic> json, PrinterBuilder builder) {
    // Splitting here the stuff e.g. for 'temperature_sensor sensor_name'

    try {
      builder.partialUpdateField(key, json);
    } catch (e, s) {
      logger.e('Error while parsing $key object', e, s);
      _printerStreamCtler.addError(e, s);
      _showParsingExceptionSnackbar(e, s, key, json);
      FirebaseCrashlytics.instance
          .recordError(e, s, reason: 'Error while parsing $key object from JSON', information: [json], fatal: true);
    }
  }

  void _parseQueriedObjects(dynamic response, PrinterBuilder printer) async {
    logger.i('<<<Received queried printer objects');
    logger.v('PrinterObjectsQuery: ${const JsonEncoder.withIndent('  ').convert(response)}');
    Map<String, dynamic> data = response['status'];

    data.forEach((key, value) {
      _parseObjectType(key, data, printer);
    });
  }

  Map<String, List<String>?> _queryPrinterObjectJson(List<String> queryableObjects) {
    final Map<String, List<String>?> queryObjects = {};
    for (String obj in queryableObjects) {
      final (cIdentifier, _) = obj.toKlipperObjectIdentifierNEW();
      if (cIdentifier == null) continue;
      queryObjects[obj] = null;
    }
    return queryObjects;
  }

  /// Query the state of queryable printer objects once!
  Future<void> _printerObjectsQuery(PrinterBuilder printer) async {
    if (disposed) return;
    logger.i('>>>Querying Printer Objects!');
    Map<String, List<String>?> queryObjects = _queryPrinterObjectJson(printer.queryableObjects);

    RpcResponse jRpcResponse =
        await _jRpcClient.sendJRpcMethod('printer.objects.query', params: {'objects': queryObjects});

    _parseQueriedObjects(jRpcResponse.result, printer);
  }

  _removeJrpcHandlers() {
    _jRpcClient.removeMethodListener(_onStatusUpdateHandler, 'notify_status_update');

    _jRpcClient.removeMethodListener(_onNotifyGcodeResponse, 'notify_gcode_response');
  }

  _registerJrpcHandlers() {
    _jRpcClient.addMethodListener(_onStatusUpdateHandler, 'notify_status_update');

    _jRpcClient.addMethodListener(_onNotifyGcodeResponse, 'notify_gcode_response');
  }

  /// This method registeres every printer object for websocket updates!
  _makeSubscribeRequest(List<String> queryableObjects) {
    logger.i('Subscribing printer objects for ws-updates!');
    Map<String, List<String>?> queryObjects = _queryPrinterObjectJson(queryableObjects);

    _jRpcClient.sendJRpcMethod('printer.objects.subscribe', params: {'objects': queryObjects}).ignore();
  }

  String _gcodeMoveCode(String axis, double value) {
    return '$axis${value <= 0 ? '' : '+'}${value.toStringAsFixed(2)}';
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

  void _showParsingExceptionSnackbar(Object e, StackTrace s, String key, Map<String, dynamic> json) {
    _snackBarService.show(SnackBarConfig(
        type: SnackbarType.error,
        title: 'Refreshing Printer failed',
        message: 'Parsing of $key failed:\n$e',
        duration: const Duration(seconds: 30),
        mainButtonTitle: 'Details',
        closeOnMainButtonTapped: true,
        onMainButtonTapped: () {
          _dialogService.show(DialogRequest(
              type: CommonDialogs.stacktrace,
              title: 'Parsing "${key.titleCase()}" failed',
              body: '$Exception:\n $e\n\n$s\n\nFailed-Key: $key \nRaw Json:\n${jsonEncode(json)}'));
        }));
  }

  void dispose() {
    _removeJrpcHandlers();

    _printerStreamCtler.close();
    _gCodeResponseStreamController.close();
  }
}
