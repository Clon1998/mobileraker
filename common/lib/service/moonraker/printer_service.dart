/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:common/data/dto/console/gcode_store_entry.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/data/dto/machine/exclude_object.dart';
import 'package:common/data/dto/machine/leds/led.dart';
import 'package:common/data/dto/machine/printer.dart';
import 'package:common/data/dto/machine/printer_axis_enum.dart';
import 'package:common/exceptions/gcode_exception.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/extensions/string_extension.dart';
import 'package:common/util/extensions/uri_extension.dart';
import 'package:common/util/logger.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stringr/stringr.dart';

import '../../data/dto/console/command.dart';
import '../../data/dto/machine/printer_builder.dart';
import '../../network/jrpc_client_provider.dart';
import '../selected_machine_service.dart';
import '../ui/dialog_service_interface.dart';
import '../ui/snackbar_service_interface.dart';
import 'file_service.dart';
import 'klippy_service.dart';

part 'printer_service.g.dart';

@riverpod
PrinterService printerService(Ref ref, String machineUUID) {
  return PrinterService(ref, machineUUID);
}

@riverpod
class PrinterNotifier extends _$PrinterNotifier {
  JsonRpcClient get _jrpcClient => ref.read(jrpcClientProvider(machineUUID));

  @override
  Future<Printer> build(String machineUUID) async {
    // Await klippy state; ref.watch registers the dependency so Riverpod
    // rebuilds this notifier whenever klipperProvider emits a new value.
    // Using .future (not .select/.selectAs) avoids the _ProviderSelector
    // disposal cascade that occurs in test environments.
    final klippy = await ref.watch(klipperProvider(machineUUID).future);

    if (!klippy.klippyConnected || !ref.mounted) {
      // Stay in loading state until klippy is connected.
      return Completer<Printer>().future;
    }

    // Register incremental status-update listener BEFORE any async ops so
    // it survives a build() error path and doesn't miss early updates.
    ref.listen(jrpcMethodEventProvider(machineUUID, 'notify_status_update'), (_, next) {
      if (!next.hasValue) return;
      _applyStatusUpdate(next.requireValue);
    });

    // Side-effect: watch own state for filename changes and klippy messages.
    listenSelf((previous, next) {
      final prevFileName = previous?.value?.print.filename;
      final nextFileName = next.value?.print.filename;
      if (prevFileName != nextFileName ||
          next.hasValue &&
              !next.hasError &&
              (nextFileName?.isNotEmpty == true && next.value?.currentFile == null ||
                  nextFileName?.isEmpty == true && next.value?.currentFile != null)) {
        _updateCurrentFile(nextFileName).ignore();
      }

      final prevMessage = previous?.value?.print.message;
      final nextMessage = next.value?.print.message;
      if (prevMessage != nextMessage && nextMessage?.isNotEmpty == true) {
        ref
            .read(snackBarServiceProvider)
            .show(SnackBarConfig(type: SnackbarType.warning, title: 'Klippy-Message', message: nextMessage));
      }
    });

    try {
      final builder = await _printerObjectsList();
      if (!ref.mounted) return Completer<Printer>().future;
      await _printerObjectsQuery(builder);
      if (!ref.mounted) return Completer<Printer>().future;
      _makeSubscribeRequest(builder.queryableObjects);
      return builder.build();
    } on JRpcTimeoutError catch (e, s) {
      talker.error('$_logTag Timeout while refreshing printer $machineUUID...', e);
      _showExceptionSnackbar(
        e,
        s,
        title: 'Refresh Printer Error',
        message: 'Timeout while trying to refresh printer',
      );
      throw MobilerakerException('Timeout while trying to refresh printer', parentException: e, parentStack: s);
    } on JRpcError catch (e, s) {
      talker.error('$_logTag Unable to refresh Printer $machineUUID...', e, s);
      _showExceptionSnackbar(e, s, title: 'Refresh Printer Error', message: 'Could not fetch printer...');
      FirebaseCrashlytics.instance.recordError(e, s, reason: 'JRpcError thrown during printer refresh');
      throw MobilerakerException('Could not fetch printer...', parentException: e, parentStack: s);
    } catch (e, s) {
      talker.error('$_logTag Unexpected exception during refresh $machineUUID...', e, s);
      _showExceptionSnackbar(e, s, title: 'Refresh Printer Error', message: 'Could not parse: $e');
      FirebaseCrashlytics.instance.recordError(e, s, reason: 'Error thrown during printer refresh');
      rethrow;
    }
  }

  /// Triggers a full re-fetch and waits until it completes.
  Future<void> refreshPrinter() async {
    state = AsyncLoading();
    ref.invalidateSelf();
    await future;
  }

  void _applyStatusUpdate(Map<String, dynamic> rawMessage) {
    final params = rawMessage['params'][0] as Map<String, dynamic>;
    state = state.whenData((current) {
      final builder = PrinterBuilder.fromPrinter(current);
      params.forEach((key, _) => _parseObjectType(key, params, builder));
      return builder.build();
    });
  }

  Future<void> _updateCurrentFile(String? file) async {
    talker.info('$_logTag Also requesting an update for current_file: $file');
    try {
      final fileService = ref.read(fileServiceProvider(machineUUID));
      final gCodeMeta = (file?.isNotEmpty == true) ? await fileService.getGCodeMetadata(file!) : null;
      talker.info('$_logTag UPDATED current_file: $gCodeMeta');
      state = state.whenData((p) => p.copyWith(currentFile: gCodeMeta));
    } catch (e, s) {
      talker.error('$_logTag Error while updating current_file', e, s);
      state = state.whenData((p) => p.copyWith(currentFile: null));
    }
  }

  Future<PrinterBuilder> _printerObjectsList() async {
    talker.info('$_logTag >>>Querying printers object list');
    final resp = await _jrpcClient.sendJRpcMethod('printer.objects.list');
    talker.info('$_logTag <<<Received printer objects list!');
    talker.verbose('$_logTag PrinterObjList: ${const JsonEncoder.withIndent('  ').convert(resp.result)}');
    return PrinterBuilder()..queryableObjects = List.unmodifiable(resp.result['objects'].cast<String>());
  }

  Future<void> _printerObjectsQuery(PrinterBuilder printer) async {
    talker.info('$_logTag >>>Querying Printer Objects!');
    final queryObjects = _queryPrinterObjectJson(printer.queryableObjects);
    final jRpcResponse = await _jrpcClient.sendJRpcMethod(
      'printer.objects.query',
      params: {'objects': queryObjects},
    );
    _parseQueriedObjects(jRpcResponse.result, printer);
  }

  void _parseQueriedObjects(dynamic response, PrinterBuilder printer) {
    talker.info('$_logTag <<<Received queried printer objects');
    talker.verbose('$_logTag PrinterObjectsQuery: ${const JsonEncoder.withIndent('  ').convert(response)}');
    final data = response['status'] as Map<String, dynamic>;
    data.forEach((key, _) => _parseObjectType(key, data, printer));
  }

  void _parseObjectType(String key, Map<String, dynamic> json, PrinterBuilder builder) {
    try {
      builder.partialUpdateField(key, json);
    } catch (e, s) {
      talker.error('$_logTag Error while parsing $key object', e, s);
      _showParsingExceptionSnackbar(e, s, key, json);
      FirebaseCrashlytics.instance.recordError(
        e,
        s,
        reason: 'Error while parsing $key object from JSON',
        information: [json],
        fatal: true,
      );
    }
  }

  void _makeSubscribeRequest(List<String> queryableObjects) {
    talker.info('$_logTag Subscribing printer objects for ws-updates!');
    final queryObjects = _queryPrinterObjectJson(queryableObjects);
    _jrpcClient.sendJRpcMethod('printer.objects.subscribe', params: {'objects': queryObjects}).ignore();
  }

  Map<String, List<String>?> _queryPrinterObjectJson(List<String> queryableObjects) {
    final queryObjects = <String, List<String>?>{};
    for (final obj in queryableObjects) {
      final (cIdentifier, _) = obj.toKlipperObjectIdentifier();
      if (cIdentifier == null) continue;
      queryObjects[obj] = null;
    }
    return queryObjects;
  }

  void _showExceptionSnackbar(Object e, StackTrace s, {required String title, required String message}) {
    ref.read(snackBarServiceProvider).showForMachine(
          machineUUID,
          SnackBarConfig.stacktraceDialog(
            dialogService: ref.read(dialogServiceProvider),
            exception: e,
            stack: s,
            snackTitle: title,
            snackMessage: message,
          ),
        );
  }

  void _showParsingExceptionSnackbar(Object e, StackTrace s, String key, Map<String, dynamic> json) {
    ref.read(snackBarServiceProvider).showForMachine(
          machineUUID,
          SnackBarConfig(
            type: SnackbarType.error,
            title: 'Refreshing Printer failed',
            message: 'Parsing of $key failed:\n$e',
            duration: const Duration(seconds: 30),
            mainButtonTitle: 'Details',
            closeOnMainButtonTapped: true,
            onMainButtonTapped: () {
              ref.read(dialogServiceProvider).show(
                    DialogRequest(
                      type: CommonDialogs.stacktrace,
                      title: 'Parsing "${key.titleCase()}" failed',
                      body: '$Exception:\n $e\n\n$s\n\nFailed-Key: $key \nRaw Json:\n${jsonEncode(json)}',
                    ),
                  );
            },
          ),
        );
  }

  String get _logTag =>
      'PrinterService@$machineUUID ${_jrpcClient.clientType}@${_jrpcClient.uri.obfuscate()}';
}

final class PrinterPreviewNotifier extends PrinterNotifier {
  @override
  Future<Printer> build(String machineUUID) async {
    return PrinterBuilder.preview().build();
  }
}

@riverpod
Future<List<Command>> printerAvailableCommands(Ref ref, String machineUUID) async {
  return ref.watch(printerServiceProvider(machineUUID)).gcodeHelp();
}

@riverpod
PrinterService printerServiceSelected(Ref ref) {
  return ref.watch(printerServiceProvider(ref.watch(selectedMachineProvider).requireValue!.uuid));
}

@riverpod
FutureOr<Printer> printerSelected(Ref ref) {
  final selectedAsync = ref.watch(selectedMachineProvider);
  if (!selectedAsync.hasValue) return Completer<Printer>().future;

  final selected = selectedAsync.requireValue;
  if (selected == null) return Completer<Printer>().future;

  // Directly forward printerProvider state. Incremental updates via
  // state.whenData(...) always produce AsyncData→AsyncData transitions and
  // return synchronously here, so callers never see a spurious loading flash.
  // Full reloads (klippy disconnect, refreshPrinter) go through AsyncLoading
  // and correctly fall through to the future, propagating the loading state.
  final printerAsync = ref.watch(printerProvider(selected.uuid));
  return switch (printerAsync) {
    AsyncData(:final value) => value,
    AsyncError(:final error, :final stackTrace) =>
      Error.throwWithStackTrace(error, stackTrace),
    _ => ref.watch(printerProvider(selected.uuid).future),
  };
}

@riverpod
class PrinterGCodeStore extends _$PrinterGCodeStore {
  @override
  FutureOr<List<GCodeStoreEntry>> build(String machineUUID) async {
    ref.keepAliveFor(Duration(minutes: 5));
    final jrpcClient = ref.watch(jrpcClientProvider(machineUUID));
    jrpcClient.addMethodListener(_onNotifyGcodeResponse, 'notify_gcode_response');
    ref.onDispose(() => jrpcClient.removeMethodListener(_onNotifyGcodeResponse, 'notify_gcode_response'));
    return await _cached(jrpcClient);
  }

  void appendCommand(String command) {
    state = state.whenData((store) => [...store, GCodeStoreEntry.command(command)]);
  }

  Future<List<GCodeStoreEntry>> _cached(JsonRpcClient jrpcClient) async {
    talker.info('[GcodeStore@${machineUUID} ${jrpcClient.clientType}@${jrpcClient.uri.obfuscate()}] Fetching cached GCode commands');
    try {
      RpcResponse blockingResponse = await jrpcClient.sendJRpcMethod('server.gcode_store');
      List<dynamic> raw = blockingResponse.result['gcode_store'];
      talker.info('[GcodeStore@${machineUUID} ${jrpcClient.clientType}@${jrpcClient.uri.obfuscate()}] Received cached GCode commands');
      return List.generate(raw.length, (index) => GCodeStoreEntry.fromJson(raw[index]));
    } on JRpcError catch (e) {
      talker.error('[GcodeStore@${machineUUID} ${jrpcClient.clientType}@${jrpcClient.uri.obfuscate()}] Error while fetching cached GCode commands: $e');
    }
    return List.empty();
  }

  void _onNotifyGcodeResponse(Map<String, dynamic> rawMessage) {
    String message = rawMessage['params'][0];
    state = state.whenData((store) => [...store, GCodeStoreEntry.response(message)]);
  }
}

/// Command facade for printer operations. State is owned by [printerProvider].
class PrinterService {
  PrinterService(this.ref, this.ownerUUID)
      : _jRpcClient = ref.watch(jrpcClientProvider(ownerUUID)),
        _snackBarService = ref.watch(snackBarServiceProvider);

  final Ref ref;
  final String ownerUUID;
  final SnackBarService _snackBarService;
  final JsonRpcClient _jRpcClient;

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

  Future<void> forceMovePrintHead({required String stepper, required distance, double feedRate = 100}) {
    return gCode('FORCE_MOVE STEPPER=$stepper DISTANCE=$distance VELOCITY=$feedRate');
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

  Future<bool> quadGantryLevel() => gCode('QUAD_GANTRY_LEVEL');

  Future<bool> m84() => gCode('M84');

  Future<bool> bedMeshLevel() => gCode('BED_MESH_CALIBRATE');

  Future<bool> zTiltAdjust() => gCode('Z_TILT_ADJUST');

  Future<bool> screwsTiltCalculate() => gCode('SCREWS_TILT_CALCULATE');

  Future<bool> probeCalibrate() => gCode('PROBE_CALIBRATE');

  Future<bool> zEndstopCalibrate() => gCode('Z_ENDSTOP_CALIBRATE');

  Future<bool> bedScrewsAdjust() => gCode('BED_SCREWS_ADJUST');

  Future<bool> selectBeaconModel(String model) => gCode('BEACON_MODEL_SELECT NAME="$model"');

  Future<bool> saveConfig() => gCode('SAVE_CONFIG');

  Future<bool> m117([String? msg]) => gCode('M117 ${msg ?? ''}');

  partCoolingFan(double perc) {
    gCode('M106 S${min(255, 255 * perc).toInt()}');
  }

  genericFanFan(String fanName, double perc) {
    gCode('SET_FAN_SPEED  FAN=$fanName SPEED=${perc.toStringAsFixed(2)}');
  }

  Future<void> outputPin(String pinName, double value) async {
    await gCode('SET_PIN PIN=$pinName VALUE=${value.toStringAsFixed(2)}');
  }

  Future<void> filamentSensor(String sensorName, bool enable) async {
    await gCode('SET_FILAMENT_SENSOR SENSOR=$sensorName ENABLE=${enable ? 1 : 0}');
  }

  Future<bool> gCode(String script, {bool throwOnError = false, bool showSnackOnErr = true}) async {
    try {
      ref.read(printerGCodeStoreProvider(ownerUUID).notifier).appendCommand(script);
      await _jRpcClient.sendJRpcMethod('printer.gcode.script', params: {'script': script}, timeout: Duration.zero);
      talker.info('$_logTag GCode "$script" executed successfully!');
      return true;
    } on JRpcError catch (e, s) {
      var gCodeException = GCodeException.fromJrpcError(e, parentStack: s);
      talker.info('$_logTag GCode execution failed: ${gCodeException.message}');
      if (showSnackOnErr) {
        _snackBarService.show(
          SnackBarConfig(type: SnackbarType.warning, title: 'GCode-Error', message: gCodeException.message),
        );
      }
      if (throwOnError) throw gCodeException;
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

  Future<bool> setHeaterTemperature(String heater, int target) {
    return gCode('SET_HEATER_TEMPERATURE  HEATER=$heater TARGET=$target');
  }

  setTemperatureFanTarget(String fan, int target) {
    gCode('SET_TEMPERATURE_FAN_TARGET TEMPERATURE_FAN=$fan TARGET=$target');
  }

  startPrintFile(GCodeFile file) {
    talker.info('$_logTag Starting print for file: ${file.pathForPrint}');
    _jRpcClient.sendJRpcMethod('printer.print.start', params: {'filename': file.pathForPrint}).ignore();
  }

  resetPrintStat() {
    gCode('SDCARD_RESET_FILE');
  }

  reprintCurrentFile() {
    var lastPrinted = ref.read(printerProvider(ownerUUID)).value?.print.filename;
    if (lastPrinted?.isNotEmpty == true) {
      _jRpcClient.sendJRpcMethod('printer.print.start', params: {'filename': lastPrinted}).ignore();
    }
  }

  Future<void> led(String ledName, Pixel pixel) async {
    await gCode(
      'SET_LED LED=$ledName RED=${pixel.red.toStringAsFixed(2)} GREEN=${pixel.green.toStringAsFixed(2)} BLUE=${pixel.blue.toStringAsFixed(2)} WHITE=${pixel.white.toStringAsFixed(2)}',
    );
  }

  Future<List<Command>> gcodeHelp() async {
    talker.info('$_logTag Fetching available GCode commands');
    try {
      RpcResponse blockingResponse = await _jRpcClient.sendJRpcMethod('printer.gcode.help');
      Map<dynamic, dynamic> raw = blockingResponse.result;
      talker.info('$_logTag Received ${raw.length} available GCode commands');
      return raw.entries.map((e) => Command(e.key, e.value)).toList();
    } on JRpcError catch (e) {
      talker.error('$_logTag Error while fetching cached GCode commands: $e');
    }
    return List.empty();
  }

  void excludeObject(ParsedObject objToExc) {
    gCode('EXCLUDE_OBJECT NAME=${objToExc.name}');
  }

  firmwareRetraction({
    double? retractLength,
    double? retractSpeed,
    double? unretractExtraLength,
    double? unretractSpeed,
  }) {
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
    await gCode('BED_MESH_PROFILE LOAD="$profileName"');
  }

  Future<void> clearBedMeshProfile() async {
    await gCode('BED_MESH_CLEAR');
  }

  String _gcodeMoveCode(String axis, double value) {
    return '$axis${value <= 0 ? '' : '+'}${value.toStringAsFixed(2)}';
  }

  String get _logTag => 'PrinterService@$ownerUUID ${_jRpcClient.clientType}@${_jRpcClient.uri.obfuscate()}';
}
