/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:common/data/dto/config/config_file.dart';
import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/data/dto/machine/bed_mesh/bed_mesh.dart';
import 'package:common/data/dto/machine/bed_screw.dart';
import 'package:common/data/dto/machine/display_status.dart';
import 'package:common/data/dto/machine/exclude_object.dart';
import 'package:common/data/dto/machine/fans/controller_fan.dart';
import 'package:common/data/dto/machine/fans/generic_fan.dart';
import 'package:common/data/dto/machine/fans/heater_fan.dart';
import 'package:common/data/dto/machine/fans/named_fan.dart';
import 'package:common/data/dto/machine/fans/print_fan.dart';
import 'package:common/data/dto/machine/fans/temperature_fan.dart';
import 'package:common/data/dto/machine/filament_sensors/filament_motion_sensor.dart';
import 'package:common/data/dto/machine/gcode_macro.dart';
import 'package:common/data/dto/machine/gcode_move.dart';
import 'package:common/data/dto/machine/heaters/extruder.dart';
import 'package:common/data/dto/machine/heaters/generic_heater.dart';
import 'package:common/data/dto/machine/heaters/heater_bed.dart';
import 'package:common/data/dto/machine/leds/addressable_led.dart';
import 'package:common/data/dto/machine/leds/dumb_led.dart';
import 'package:common/data/dto/machine/leds/led.dart';
import 'package:common/data/dto/machine/manual_probe.dart';
import 'package:common/data/dto/machine/motion_report.dart';
import 'package:common/data/dto/machine/output_pin.dart';
import 'package:common/data/dto/machine/print_stats.dart';
import 'package:common/data/dto/machine/printer.dart';
import 'package:common/data/dto/machine/printer_axis_enum.dart';
import 'package:common/data/dto/machine/screws_tilt_adjust/screws_tilt_adjust.dart';
import 'package:common/data/dto/machine/temperature_sensor.dart';
import 'package:common/data/dto/machine/toolhead.dart';
import 'package:common/data/dto/machine/virtual_sd_card.dart';
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
import '../../data/dto/machine/filament_sensors/filament_sensor.dart';
import '../../data/dto/machine/firmware_retraction.dart';
import '../../data/dto/machine/z_thermal_adjust.dart';
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
    var previousFileName = previous?.valueOrNull?.print.filename;
    var nextFileName = next.valueOrNull?.print.filename;
    // The 2nd case is to cover rare race conditions where a printer update was issued at the same time as this code was executed
    if (previousFileName != nextFileName ||
        next.hasValue &&
            (nextFileName?.isNotEmpty == true && next.value?.currentFile == null ||
                nextFileName?.isEmpty == true && next.value?.currentFile != null)) {
      printerService.updateCurrentFile(nextFileName).ignore();
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
    'heater_fan': _updateFan,
    'controller_fan': _updateFan,
    'temperature_fan': _updateFan,
    'fan_generic': _updateFan,
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
    'screws_tilt_adjust': _updateScrewsTiltAdjust,
    'heater_generic': _updateGenericHeater,
    'firmware_retraction': _updateFirmwareRetraction,
    'bed_mesh': _updateBedMesh,
    'filament_switch_sensor': _updateFilamentSensor,
    'filament_motion_sensor': _updateFilamentSensor,
    'z_thermal_adjust': _updateZThermalAdjust,
    'gcode_macro': _updateGcodeMacro,
  };

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

  _parseObjectType(String key, Map<String, dynamic> json, PrinterBuilder printer) {
    // Splitting here the stuff e.g. for 'temperature_sensor sensor_name'
    var klipperObjectIdentifier = key.toKlipperObjectIdentifier();
    var objectIdentifier = klipperObjectIdentifier.$1;
    var objectName = klipperObjectIdentifier.$2;

    try {
      if (_subToPrinterObjects.containsKey(objectIdentifier)) {
        var method = _subToPrinterObjects[objectIdentifier];
        if (method != null) {
          if (objectName != null) {
            method(objectName, json[key], printer: printer);
          } else {
            method(json[key], printer: printer);
          }
        }
      } else if (objectIdentifier.startsWith('extruder')) {
        // Note that extruder will be handled above!
        _updateExtruder(json[key], printer: printer, num: int.tryParse(objectIdentifier.substring(8)) ?? 0);
      }
    } catch (e, s) {
      logger.e('Error while parsing $key object', e, s);
      _printerStreamCtler.addError(e, s);
      _showParsingExceptionSnackbar(e, s, key, json);
      FirebaseCrashlytics.instance
          .recordError(e, s, reason: 'Error while parsing $key object from JSON', information: [json], fatal: true);
    }
  }

  /// Parses the list of printer objects received from the server.
  ///
  /// This method takes a Map of printer objects and processes each object
  /// based on its type. It creates a new PrinterBuilder and populates it
  /// with the parsed printer objects.
  ///
  /// The method handles different types of printer objects including
  /// extruders, fans, temperature sensors, output pins, LEDs, heaters, etc.
  /// For each type of object, it calls the appropriate method to parse
  /// the object and add it to the PrinterBuilder.
  ///
  /// @param result A Map of printer objects received from the server.
  /// Each key in the Map is the name of a printer object and the value
  /// is a Map of properties for that object.
  ///
  /// @return A PrinterBuilder populated with the parsed printer objects.
  _parsePrinterObjectsList(Map<String, dynamic> result) {
    logger.i('<<<Received printer objects list!');
    logger.v('PrinterObjList: ${const JsonEncoder.withIndent('  ').convert(result)}');
    PrinterBuilder printerBuilder = PrinterBuilder();

    List<String> objects = result['objects'].cast<String>();
    List<String> qObjects = [];
    int extruderCnt = 0;

    for (String rawObject in objects) {
      qObjects.add(rawObject);
      var klipperObjectIdentifier = rawObject.toKlipperObjectIdentifier();
      String objectIdentifier = klipperObjectIdentifier.$1;
      String objectName = klipperObjectIdentifier.$2 ?? klipperObjectIdentifier.$1;

      if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.gcode_macro)) {
        printerBuilder.gcodeMacros[objectName] = GcodeMacro(name: objectName);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.extruder)) {
        int extNum = int.tryParse(objectIdentifier.substring(8)) ?? 0;
        extruderCnt = max(extNum + 1, extruderCnt);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.heater_fan)) {
        printerBuilder.fans[objectName] = HeaterFan(name: objectName);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.controller_fan)) {
        printerBuilder.fans[objectName] = ControllerFan(name: objectName);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.temperature_fan)) {
        printerBuilder.fans[objectName] = TemperatureFan(
          name: objectName,
          lastHistory: DateTime(1990),
        );
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.fan_generic)) {
        printerBuilder.fans[objectName] = GenericFan(name: objectName);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.output_pin)) {
        printerBuilder.outputPins[objectName] = OutputPin(name: objectName);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.temperature_sensor)) {
        printerBuilder.temperatureSensors[objectName] = TemperatureSensor(
          name: objectName,
          lastHistory: DateTime(1990),
        );
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.led)) {
        printerBuilder.leds[objectName] = DumbLed(name: objectName);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.pca9533)) {
        printerBuilder.leds[objectName] = DumbLed(name: objectName);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.pca9632)) {
        printerBuilder.leds[objectName] = DumbLed(name: objectName);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.neopixel)) {
        printerBuilder.leds[objectName] = AddressableLed(name: objectName);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.dotstar)) {
        printerBuilder.leds[objectName] = AddressableLed(name: objectName);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.heater_generic)) {
        printerBuilder.genericHeaters[objectName] = GenericHeater(
          name: objectName,
          lastHistory: DateTime(1990),
        );
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.bed_mesh)) {
        printerBuilder.bedMesh = const BedMesh();
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.filament_switch_sensor)) {
        printerBuilder.filamentSensors[objectName] = FilamentMotionSensor(name: objectName);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.filament_motion_sensor)) {
        printerBuilder.filamentSensors[objectName] = FilamentMotionSensor(name: objectName);
      } else if (objectIdentifier.isKlipperObject(ConfigFileObjectIdentifiers.z_thermal_adjust)) {
        printerBuilder.zThermalAdjust = ZThermalAdjust(lastHistory: DateTime(1990));
      }
    }
    printerBuilder.extruders =
        List.generate(extruderCnt, (index) => Extruder(num: index, lastHistory: DateTime(1990)), growable: false);
    printerBuilder.queryableObjects = List.unmodifiable(qObjects);

    return printerBuilder;
  }

  _parseQueriedObjects(dynamic response, PrinterBuilder printer) async {
    logger.i('<<<Received queried printer objects');
    logger.v('PrinterObjectsQuery: ${const JsonEncoder.withIndent('  ').convert(response)}');
    Map<String, dynamic> data = response['status'];

    data.forEach((key, value) {
      _parseObjectType(key, data, printer);
    });
  }

  _updatePrintFan(Map<String, dynamic> jsonResponse, {required PrinterBuilder printer}) {
    printer.printFan = PrintFan.partialUpdate(printer.printFan, jsonResponse);
  }

  _updateFan(String fanName, Map<String, dynamic> fanJson, {required PrinterBuilder printer}) {
    final curFan = printer.fans[fanName];

    if (curFan == null) {
      logger.e('Fan $fanName not found in printer.fans');
      throw MobilerakerException('Fan $fanName not found in printer.fans');
    }

    NamedFan updated = NamedFan.partialUpdate(curFan, fanJson);
    printer.fans = {...printer.fans, fanName: updated};
  }

  _updateTemperatureSensor(String sensorName, Map<String, dynamic> sensorJson, {required PrinterBuilder printer}) {
    TemperatureSensor current = printer.temperatureSensors[sensorName]!;

    printer.temperatureSensors = {
      ...printer.temperatureSensors,
      sensorName: TemperatureSensor.partialUpdate(current, sensorJson)
    };
  }

  _updateOutputPin(String pin, Map<String, dynamic> pinJson, {required PrinterBuilder printer}) {
    OutputPin curPin = printer.outputPins[pin]!;

    printer.outputPins = {...printer.outputPins, pin: OutputPin.partialUpdate(curPin, pinJson)};
  }

  _updateGCodeMove(Map<String, dynamic> jsonResponse, {required PrinterBuilder printer}) {
    printer.gCodeMove = GCodeMove.partialUpdate(printer.gCodeMove, jsonResponse);
  }

  _updateMotionReport(Map<String, dynamic> jsonResponse, {required PrinterBuilder printer}) {
    printer.motionReport = MotionReport.partialUpdate(printer.motionReport, jsonResponse);
  }

  _updateDisplayStatus(Map<String, dynamic> jsonResponse, {required PrinterBuilder printer}) {
    printer.displayStatus = DisplayStatus.partialUpdate(
      printer.displayStatus,
      jsonResponse,
    );
  }

  _updateVirtualSd(Map<String, dynamic> jsonResponse, {required PrinterBuilder printer}) {
    printer.virtualSdCard = VirtualSdCard.partialUpdate(printer.virtualSdCard, jsonResponse);
  }

  _updatePrintStat(Map<String, dynamic> jsonResponse, {required PrinterBuilder printer}) {
    if (jsonResponse.containsKey('message')) {
      _onMessage(jsonResponse['message']!);
    }

    printer.print = PrintStats.partialUpdate(printer.print, jsonResponse);
  }

  _updateConfigFile(Map<String, dynamic> jsonResponse, {required PrinterBuilder printer}) {
    var config = printer.configFile ?? ConfigFile();
    if (jsonResponse.containsKey('settings')) {
      config = ConfigFile.parse(jsonResponse['settings']);
    }
    if (jsonResponse.containsKey('save_config_pending')) {
      config.saveConfigPending = jsonResponse['save_config_pending'];
    }
    printer.configFile = config;
  }

  _updateHeaterBed(Map<String, dynamic> jsonResponse, {required PrinterBuilder printer}) {
    printer.heaterBed = HeaterBed.partialUpdate(printer.heaterBed, jsonResponse);
  }

  _updateGenericHeater(String configName, Map<String, dynamic> jsonResponse, {required PrinterBuilder printer}) {
    printer.genericHeaters = {
      ...printer.genericHeaters,
      configName: GenericHeater.partialUpdate(printer.genericHeaters[configName]!, jsonResponse)
    };
  }

  _updateExtruder(Map<String, dynamic> jsonResponse, {required PrinterBuilder printer, int num = 0}) {
    List<Extruder> extruders = printer.extruders;
    Extruder extruder = printer.extruders[num];

    Extruder newExtruder = Extruder.partialUpdate(extruder, jsonResponse);

    printer.extruders = extruders.mapIndex((e, i) => i == num ? newExtruder : e).toList(growable: false);
  }

  _updateToolhead(Map<String, dynamic> jsonResponse, {required PrinterBuilder printer}) {
    printer.toolhead = Toolhead.partialUpdate(printer.toolhead, jsonResponse);
  }

  _updateExcludeObject(Map<String, dynamic> jsonResponse, {required PrinterBuilder printer}) {
    printer.excludeObject = ExcludeObject.partialUpdate(printer.excludeObject, jsonResponse);
  }

  _updateLed(String led, Map<String, dynamic> jsonResponse, {required PrinterBuilder printer}) {
    printer.leds = {...printer.leds, led: Led.partialUpdate(printer.leds[led]!, jsonResponse)};
  }

  _updateManualProbe(Map<String, dynamic> jsonResponse, {required PrinterBuilder printer}) {
    printer.manualProbe = ManualProbe.partialUpdate(printer.manualProbe, jsonResponse);
  }

  _updateBedScrew(Map<String, dynamic> jsonResponse, {required PrinterBuilder printer}) {
    printer.bedScrew = BedScrew.partialUpdate(printer.bedScrew, jsonResponse);
  }

  _updateScrewsTiltAdjust(Map<String, dynamic> jsonResponse, {required PrinterBuilder printer}) {
    printer.screwsTiltAdjust = ScrewsTiltAdjust.partialUpdate(printer.screwsTiltAdjust, jsonResponse);
  }

  _updateFirmwareRetraction(Map<String, dynamic> jsonResponse, {required PrinterBuilder printer}) {
    printer.firmwareRetraction = FirmwareRetraction.partialUpdate(printer.firmwareRetraction, jsonResponse);
  }

  _updateBedMesh(Map<String, dynamic> jsonResponse, {required PrinterBuilder printer}) {
    printer.bedMesh = BedMesh.partialUpdate(printer.bedMesh, jsonResponse);
  }

  _updateFilamentSensor(String sensor, Map<String, dynamic> jsonResponse, {required PrinterBuilder printer}) {
    printer.filamentSensors = {
      ...printer.filamentSensors,
      sensor: FilamentSensor.partialUpdate(printer.filamentSensors[sensor]!, jsonResponse)
    };
  }

  _updateZThermalAdjust(Map<String, dynamic> jsonResponse, {required PrinterBuilder printer}) {
    printer.zThermalAdjust = ZThermalAdjust.partialUpdate(printer.zThermalAdjust, jsonResponse);
  }

  _updateGcodeMacro(String macro, Map<String, dynamic> inputJson, {required PrinterBuilder printer}) {
    final curObj = printer.gcodeMacros[macro]!;

    printer.gcodeMacros = {...printer.gcodeMacros, macro: GcodeMacro.partialUpdate(curObj, inputJson)};
  }

  Map<String, List<String>?> _queryPrinterObjectJson(List<String> queryableObjects) {
    Map<String, List<String>?> queryObjects = {};
    for (String ele in queryableObjects) {
      // Splitting here the stuff e.g. for 'temperature_sensor sensor_name'
      var klipperObjectIdentifier = ele.toKlipperObjectIdentifier();
      String objTypeKey = klipperObjectIdentifier.$1;

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

  _onMessage(String message) {
    if (message.isEmpty) return;
    _snackBarService.show(SnackBarConfig(type: SnackbarType.warning, title: 'Klippy-Message', message: message));
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

  dispose() {
    _removeJrpcHandlers();

    _printerStreamCtler.close();
    _gCodeResponseStreamController.close();
  }
}
