/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
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
KlippyService klipperService(KlipperServiceRef ref, String machineUUID) {
  return KlippyService(ref, machineUUID);
}

@riverpod
Stream<KlipperInstance> klipper(KlipperRef ref, String machineUUID) {
  return ref.watch(klipperServiceProvider(machineUUID)).klipperStream;
}

@riverpod
KlippyService klipperServiceSelected(KlipperServiceSelectedRef ref) {
  return ref.watch(klipperServiceProvider(ref.watch(selectedMachineProvider).requireValue!.uuid));
}

@riverpod
Stream<KlipperInstance> klipperSelected(KlipperSelectedRef ref) async* {
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
      logger.i(
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

  final AutoDisposeRef ref;

  final JsonRpcClient _jRpcClient;

  final StreamController<KlipperInstance> _klipperStreamCtler = StreamController();

  Stream<KlipperInstance> get klipperStream => _klipperStreamCtler.stream;

  KlipperInstance __current = KlipperInstance(moonrakerVersion: MoonrakerVersion.fallback());

  set _current(KlipperInstance nI) {
    __current = nI;
    if (!_klipperStreamCtler.isClosed) {
      _klipperStreamCtler.add(nI);
    }
  }

  KlipperInstance get _current => __current;

  bool get isKlippyConnected => _current.klippyConnected;

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
      await _identifyConnection();
      var klippyReady = await _fetchServerInfo();
      logger.i('KlippyReady: $klippyReady');
      // We can only fetch the printer info if klippy reported ready (So klippy domain is connected to moonraker)
      if (klippyReady) {
        await _fetchPrinterInfo();
      }
    } on JRpcError catch (e, s) {
      logger.w('Jrpc Error while refreshing KlippyObject: ${e.message}');

      _updateError(MobilerakerException('Error while refreshing KlippyObject', parentException: e), s);
      // _current = _current.copyWith(
      //     klippyConnected: false,
      //     klippyState: (e.message == 'Unauthorized') ? KlipperState.unauthorized : KlipperState.error,
      //     klippyStateMessage: e.message);
    }
  }

  void _updateError(Object error, StackTrace stackTrace) {
    if (!_klipperStreamCtler.isClosed) {
      _klipperStreamCtler.addError(error, stackTrace);
    }
  }

  /// Fetches server information via JSON-RPC and initializes KlipperInstance.
  /// Sends a "server.info" request using [_jRpcClient], logs start and completion.
  /// Deserializes the response into a [KlipperInstance], updates [_current], and
  /// returns the Klippy server connection status.
  Future<bool> _fetchServerInfo() async {
    logger.i('>>>Fetching Server.Info');
    RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod('server.info');
    logger.i('<<<Received Server.Info');
    logger.v('ServerInfo: ${const JsonEncoder.withIndent('  ').convert(rpcResponse.result)}');

    // Server info is the first request and should therfore initialize the KlipperInstance
    var instance = KlipperInstance.fromJson(rpcResponse.result);
    _current = instance;
    return instance.klippyConnected;
  }

  Future<void> _fetchPrinterInfo() async {
    logger.i('>>>rpcResponse Printer.Info');
    RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod('printer.info');
    logger.i('<<<Received Printer.Info');
    logger.v('PrinterInfo: ${const JsonEncoder.withIndent('  ').convert(rpcResponse.result)}');

    // Printer info is the second request and should therfore update the KlipperInstance
    _current = KlipperInstance.partialUpdate(_current, rpcResponse.result);
  }

  Future<void> _identifyConnection() async {
    var version = await ref.read(versionInfoProvider.future);
    var machine = await ref.read(machineProvider(ownerUUID).future);

    await _jRpcClient.identifyConnection(version, machine?.apiKey);
  }

  _onNotifyKlippyReady(Map<String, dynamic> m) {
    _current = _current.copyWith(klippyState: KlipperState.ready, klippyConnected: true, klippyStateMessage: null);
    logger.i('State: notify_klippy_ready');
    // Just to be sure, fetch all klippy info again
    refreshKlippy().ignore();
  }

  _onNotifyKlippyShutdown(Map<String, dynamic> m) async {
    _current = _current.copyWith(klippyState: KlipperState.shutdown, klippyStateMessage: null);
    logger.i('State: notify_klippy_shutdown');
    // Just to be sure, fetch all klippy info again (Also fetches the statusMessage that contains the shutdown reason)
    refreshKlippy().ignore();
  }

  _onNotifyKlippyDisconnected(Map<String, dynamic> m) {
    _current =
        _current.copyWith(klippyConnected: false, klippyState: KlipperState.disconnected, klippyStateMessage: null);
    logger.i('State: notify_klippy_disconnected: $m');
    // NO need to call refreshKlippy() here, because we can not get printer.info if klippy HOST is not connected with Moonraker
  }

  dispose() {
    _jRpcClient.removeMethodListener(_onNotifyKlippyReady, 'notify_klippy_ready');
    _jRpcClient.removeMethodListener(_onNotifyKlippyShutdown, 'notify_klippy_shutdown');
    _jRpcClient.removeMethodListener(_onNotifyKlippyDisconnected, 'notify_klippy_disconnected');

    _klipperStreamCtler.close();
  }
}
