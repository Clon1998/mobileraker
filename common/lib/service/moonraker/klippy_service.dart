/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:convert';

import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/misc_providers.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/extensions/uri_extension.dart';
import 'package:common/util/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/dto/server/klipper.dart';
import '../../data/dto/server/moonraker_version.dart';
import '../../network/jrpc_client_provider.dart';
import '../selected_machine_service.dart';

part 'klippy_service.g.dart';

@Riverpod()
class Klipper extends _$Klipper {
  JsonRpcClient get _jrpcClient => ref.read(jrpcClientProvider(machineUUID));

  @override
  Future<KlipperInstance> build(String machineUUID) async {
    final clientState = await ref.watch(jrpcClientStateProvider(machineUUID).future);

    if (clientState != ClientState.connected) {
      return KlipperInstance(
        moonrakerVersion: MoonrakerVersion.fallback(),
        klippyConnected: false,
        klippyState: clientState == ClientState.error ? KlipperState.error : KlipperState.disconnected,
      );
    }

    // Set up notification listeners before any async ops so they survive a build() error.
    ref.listen(jrpcMethodEventProvider(machineUUID, 'notify_klippy_ready'), (_, next) {
      if (!next.hasValue) return;
      talker.info('$_logTag notify_klippy_ready received, triggering rebuild');
      ref.invalidateSelf();
    });
    ref.listen(jrpcMethodEventProvider(machineUUID, 'notify_klippy_shutdown'), (_, next) {
      if (!next.hasValue) return;
      talker.info('$_logTag notify_klippy_shutdown received, triggering rebuild');
      ref.invalidateSelf();
    });
    ref.listen(jrpcMethodEventProvider(machineUUID, 'notify_klippy_disconnected'), (_, next) {
      if (!next.hasValue) return;
      talker.info('$_logTag notify_klippy_disconnected received, triggering rebuild');
      ref.invalidateSelf();
    });

    await _identifyConnection();
    if (!ref.mounted) return state.value ?? KlipperInstance(moonrakerVersion: MoonrakerVersion.fallback());

    KlipperInstance instance = state.value ?? KlipperInstance(moonrakerVersion: MoonrakerVersion.fallback());

    // Poll until klippy domain is connected to moonraker.
    do {
      talker.info('$_logTag Checking if Klippy is connected...');
      instance = await _fetchServerInfo();
      talker.info('$_logTag Klippy connection status: ${instance.klippyConnected ? "Connected" : "Disconnected"}');
      if (!instance.klippyConnected && ref.mounted) {
        await Future.delayed(const Duration(seconds: 2));
      }
    } while (!instance.klippyConnected && ref.mounted);

    if (!ref.mounted) return instance;

    // Poll until klipper reaches ready state.
    do {
      talker.info('$_logTag Checking Klippy state...');
      instance = await _fetchPrinterInfo(instance);
      talker.info('$_logTag Current Klippy state: ${instance.klippyState}');
      if (instance.klippyState != KlipperState.ready && ref.mounted) {
        await Future.delayed(const Duration(seconds: 2));
      }
    } while (instance.klippyState != KlipperState.ready && ref.mounted);

    return instance;
  }

  /// Triggers a full re-poll and waits until it completes.
  Future<void> refreshKlippy() async {
    // Set loading first so that `future` becomes a new pending Future before the rebuild.
    state = AsyncLoading();
    ref.invalidateSelf();
    await future;
  }

  Future<KlipperInstance> _fetchServerInfo() async {
    talker.info('$_logTag >>>Fetching Server.Info');
    final RpcResponse rpcResponse = await _jrpcClient.sendJRpcMethod('server.info');
    talker.info('$_logTag <<<Received Server.Info');
    talker.verbose('$_logTag ServerInfo: ${const JsonEncoder.withIndent('  ').convert(rpcResponse.result)}');
    return KlipperInstance.fromJson(rpcResponse.result);
  }

  Future<KlipperInstance> _fetchPrinterInfo(KlipperInstance current) async {
    talker.info('$_logTag >>>Fetching Printer.Info');
    final RpcResponse rpcResponse = await _jrpcClient.sendJRpcMethod('printer.info');
    talker.info('$_logTag <<<Received Printer.Info');
    talker.verbose('$_logTag PrinterInfo: ${const JsonEncoder.withIndent('  ').convert(rpcResponse.result)}');
    return KlipperInstance.partialUpdate(current, {
      ...rpcResponse.result,
      // printer.info returns "state" rather than "klippy_state"
      if (rpcResponse.result.containsKey('state')) 'klippy_state': rpcResponse.result['state'],
    });
  }

  Future<void> _identifyConnection() async {
    final version = await ref.read(versionInfoProvider.future);
    final machine = await ref.read(machineProvider(machineUUID).future);
    await _jrpcClient.identifyConnection(version, machine?.apiKey);
  }

  String get _logTag => '[Klipper@$machineUUID ${_jrpcClient.clientType}@${_jrpcClient.uri.obfuscate()}]';
}

@riverpod
KlippyService klipperService(Ref ref, String machineUUID) {
  return KlippyService(ref, machineUUID);
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

/// Provides klippy command methods. State is owned by [klipperProvider].
class KlippyService {
  final String ownerUUID;
  final Ref ref;

  KlippyService(this.ref, this.ownerUUID);

  JsonRpcClient get _jRpcClient => ref.read(jrpcClientProvider(ownerUUID));

  void restartMCUs() {
    _jRpcClient.sendJRpcMethod('printer.firmware_restart').ignore();
  }

  void rebootHost() {
    _jRpcClient.sendJRpcMethod('machine.reboot').ignore();
  }

  void shutdownHost() {
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

  void emergencyStop() {
    _jRpcClient.sendJRpcMethod('printer.emergency_stop').ignore();
  }
}
