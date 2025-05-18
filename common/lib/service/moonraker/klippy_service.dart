/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:convert';

import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/misc_providers.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/extensions/uri_extension.dart';
import 'package:common/util/logger.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/dto/server/klipper.dart';
import '../../data/dto/server/moonraker_version.dart';
import '../../network/jrpc_client_provider.dart';
import '../selected_machine_service.dart';

part 'klippy_service.g.dart';

@riverpod
KlippyService klipperService(Ref ref, String machineUUID) {
  return KlippyService(ref, machineUUID);
}

@riverpod
Stream<KlipperInstance> klipper(Ref ref, String machineUUID) {
  ref.watch(signalingHelperProvider('klipper-$machineUUID'));
  return ref.watch(klipperServiceProvider(machineUUID)).klipperStream;
}

@riverpod
KlippyService klipperServiceSelected(Ref ref) {
  return ref.watch(klipperServiceProvider(ref.watch(selectedMachineProvider).requireValue!.uuid));
}

@riverpod
Stream<KlipperInstance> klipperSelected(Ref ref) async* {
  try {
    var machine = await ref.watch(selectedMachineProvider.future);
    if (machine == null) return;
    yield* ref.watchAsSubject(klipperProvider(machine.uuid));
  } on StateError catch (_) {
    // Just catch it. It is expected that the future/where might not complete!
  }
}

/// Service managing klippy-server stuff
class KlippyService {
  String ownerUUID;

  KlippyService(this.ref, this.ownerUUID) : _jRpcClient = ref.watch(jrpcClientProvider(ownerUUID)) {
    ref.onDispose(dispose);

    _jRpcClient.addMethodListener(_onNotifyKlippyReady, 'notify_klippy_ready');
    _jRpcClient.addMethodListener(_onNotifyKlippyShutdown, 'notify_klippy_shutdown');
    _jRpcClient.addMethodListener(_onNotifyKlippyDisconnected, 'notify_klippy_disconnected');

    ref.listen(jrpcClientStateProvider(ownerUUID), (previous, next) {
      talker.info(
          '[Klippy Service ${_jRpcClient.clientType}@${_jRpcClient.uri.obfuscate()}] Received new JRpcClientState: $previous -> $next');
      switch (next.valueOrFullNull) {
        case ClientState.connected:
          refreshKlippy().ignore();
          break;
        case ClientState.error:
          _current = _current.copyWith(klippyConnected: false, klippyState: KlipperState.error);
          break;
        case ClientState.disconnected:
          _current = _current.copyWith(klippyConnected: false, klippyState: KlipperState.disconnected);
        default:
      }
    }, fireImmediately: true);
  }

  final Ref ref;

  final JsonRpcClient _jRpcClient;

  final StreamController<KlipperInstance> _klipperStreamCtler = StreamController.broadcast();

  Stream<KlipperInstance> get klipperStream => _klipperStreamCtler.stream;

  KlipperInstance __current = KlipperInstance(moonrakerVersion: MoonrakerVersion.fallback());

  Timer? _checkKlippyConnectedTimer;

  Timer? _checkKlippyStateTimer;

  set _current(KlipperInstance nI) {
    __current = nI;
    if (!_klipperStreamCtler.isClosed) {
      _klipperStreamCtler.add(nI);
    }
  }

  KlipperInstance get _current => __current;

  bool get isKlippyConnected => _current.klippyConnected;

  bool get klippyCanReceiveCommands => _current.klippyCanReceiveCommands;

  restartMCUs() {
    _jRpcClient.sendJRpcMethod('printer.firmware_restart').ignore();
  }

  rebootHost() {
    _jRpcClient.sendJRpcMethod('machine.reboot').ignore();
  }

  shutdownHost() {
    _jRpcClient.sendJRpcMethod('machine.shutdown').ignore();
  }

  Future<void> restartKlipper() {
    return restartService('klipper');
  }

  Future<void> restartService(String service) async {
    await _jRpcClient.sendJRpcMethod('machine.services.restart', params: {'service': service});
  }

  Future<void> stopService(String service) async {
    await _jRpcClient.sendJRpcMethod('machine.services.stop', params: {'service': service});
  }

  Future<void> startService(String service) async {
    await _jRpcClient.sendJRpcMethod('machine.services.start', params: {'service': service});
  }

  emergencyStop() {
    _jRpcClient.sendJRpcMethod('printer.emergency_stop').ignore();
  }

  Future<void> refreshKlippy() async {
    try {
      ref.invalidate(signalingHelperProvider('klipper-$ownerUUID'));
      await _identifyConnection();

      _checkKlippyConnected();
    } on JRpcError catch (e, s) {
      talker.warning('Jrpc Error while refreshing KlippyObject: ${e.message}');

      _updateError(MobilerakerException('Error while refreshing KlippyObject', parentException: e), s);
    }
  }

  void _updateError(Object error, StackTrace stackTrace) {
    if (!_klipperStreamCtler.isClosed) {
      _klipperStreamCtler.addError(error, stackTrace);
    }
  }

  void _startKlippyConnectedTimer() {
    if (_checkKlippyConnectedTimer != null && _checkKlippyConnectedTimer!.isActive) {
      talker.warning('Klippy connection timer is already active and running! Skipping new timer creation.');
      return;
    }

    // For safety, still cancel any existing timer
    _checkKlippyConnectedTimer?.cancel();
    _checkKlippyConnectedTimer = Timer(Duration(seconds: 2), _checkKlippyConnected);
    talker.info('Started Klippy connection check timer (will check again in 2s)');
  }

  void _checkKlippyConnected() async {
    try {
      talker.info('Checking if Klippy is connected...');
      var instance = await _fetchServerInfo();
      _current = instance;
      talker.info('Klippy connection status: ${instance.klippyConnected ? "Connected" : "Disconnected"}');

      // We can only fetch the printer info if klippy reported ready (So klippy domain is connected to moonraker)
      if (instance.klippyConnected) {
        talker.info('Klippy is connected, proceeding to request printer.info');
        _checkKlippyState();
      } else {
        talker.info('Klippy is not connected, scheduling another connection check');
        // This is done to update the klippy state!
        _startKlippyConnectedTimer();
      }
    } on JRpcError catch (e, s) {
      talker.warning('Jrpc Error while checking Klippy connection: ${e.message}');
      _updateError(MobilerakerException('Error while checking Klippy connection', parentException: e), s);
    }
  }

  void _startKlippyStateTimer() {
    if (_checkKlippyStateTimer != null && _checkKlippyStateTimer!.isActive) {
      talker.warning('Klippy state timer is already active and running! Skipping new timer creation.');
      return;
    }

    // For safety, still cancel any existing timer
    _checkKlippyStateTimer?.cancel();
    _checkKlippyStateTimer = Timer(Duration(seconds: 2), _checkKlippyState);
    talker.info('Started Klippy state check timer (will check again in 2s)');
  }

  void _checkKlippyState() async {
    try {
      talker.info('Checking Klippy state...');
      // Printer info is the second request and should therfore update the KlipperInstance
      final instance = await _fetchPrinterInfo();
      _current = instance;

      talker.info('Current Klippy state: ${instance.klippyState}');

      if (instance.klippyState != KlipperState.ready) {
        talker.info('Klippy not in ready state yet (current: ${instance.klippyState}), scheduling another state check');
        // We need to keep asking for the klippy state until it is ready because not all state transitions
        // are notification based (only ready, shutdown, error)
        _startKlippyStateTimer();
      } else {
        talker.info('Klippy is in ready state! All systems operational.');
      }
    } on JRpcError catch (e, s) {
      talker.warning('Jrpc Error while checking Klippy state: ${e.message}');
      _updateError(MobilerakerException('Error while checking Klippy state', parentException: e), s);
    }
  }

  /// Fetches server information via JSON-RPC and initializes KlipperInstance.
  /// Sends a "server.info" request using [_jRpcClient], logs start and completion.
  /// Deserializes the response into a [KlipperInstance], updates [_current], and
  /// returns the Klippy server connection status.
  Future<KlipperInstance> _fetchServerInfo() async {
    talker.info('>>>Fetching Server.Info');
    RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod('server.info');
    talker.info('<<<Received Server.Info');
    talker.verbose('ServerInfo: ${const JsonEncoder.withIndent('  ').convert(rpcResponse.result)}');

    // Server info is the first request and should therfore initialize the KlipperInstance
    var instance = KlipperInstance.fromJson(rpcResponse.result);
    return instance;
  }

  Future<KlipperInstance> _fetchPrinterInfo() async {
    talker.info('>>>Fetching Printer.Info');
    RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod('printer.info');
    talker.info('<<<Received Printer.Info');
    talker.verbose('PrinterInfo: ${const JsonEncoder.withIndent('  ').convert(rpcResponse.result)}');

    // Log the state mapping for better debugging
    if (rpcResponse.result.containsKey('state')) {
      talker.info('Mapping printer.info "state" (${rpcResponse.result['state']}) to "klippy_state"');
    } else {
      talker.warning('printer.info response does not contain "state" field');
    }

    var instance = KlipperInstance.partialUpdate(_current, {
      ...rpcResponse.result,
      // We need to adjust the state because printer.info returns "state" rather than "klippy_state"!
      if (rpcResponse.result.containsKey('state')) 'klippy_state': rpcResponse.result['state'],
    });

    return instance;
  }

  Future<void> _identifyConnection() async {
    var version = await ref.read(versionInfoProvider.future);
    var machine = await ref.read(machineProvider(ownerUUID).future);

    await _jRpcClient.identifyConnection(version, machine?.apiKey);
  }

  _onNotifyKlippyReady(Map<String, dynamic> m) {
    _current = _current.copyWith(klippyState: KlipperState.ready, klippyConnected: true, klippyStateMessage: null);
    talker.info('State: notify_klippy_ready');
    // Just to be sure, fetch all klippy info again
    refreshKlippy().ignore();
  }

  _onNotifyKlippyShutdown(Map<String, dynamic> m) async {
    _current = _current.copyWith(klippyState: KlipperState.shutdown, klippyStateMessage: null);
    talker.info('State: notify_klippy_shutdown');
    // Just to be sure, fetch all klippy info again (Also fetches the statusMessage that contains the shutdown reason)
    refreshKlippy().ignore();
  }

  _onNotifyKlippyDisconnected(Map<String, dynamic> m) {
    _current =
        _current.copyWith(klippyConnected: false, klippyState: KlipperState.disconnected, klippyStateMessage: null);
    talker.info('State: notify_klippy_disconnected: $m');
    refreshKlippy().ignore();
  }

  dispose() {
    _jRpcClient.removeMethodListener(_onNotifyKlippyReady, 'notify_klippy_ready');
    _jRpcClient.removeMethodListener(_onNotifyKlippyShutdown, 'notify_klippy_shutdown');
    _jRpcClient.removeMethodListener(_onNotifyKlippyDisconnected, 'notify_klippy_disconnected');

    _klipperStreamCtler.close();
  }
}
