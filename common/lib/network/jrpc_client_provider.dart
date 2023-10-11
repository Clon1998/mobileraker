/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/model/hive/machine.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/firebase/remote_config.dart';
import 'package:common/service/misc_providers.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../service/machine_service.dart';
import '../service/selected_machine_service.dart';

part 'jrpc_client_provider.g.dart';

@riverpod
JsonRpcClient _jsonRpcClient(_JsonRpcClientRef ref, String machineUUID, ClientType type) {
  var machine = ref.watch(machineProvider(machineUUID)).valueOrNull;

  if (machine == null) {
    throw MobilerakerException('Machine with UUID "$machineUUID" was not found!');
  }

  JsonRpcClient jsonRpcClient = JsonRpcClientBuilder.fromClientType(type, machine).build();
  logger.i('${jsonRpcClient.logPrefix} JsonRpcClient CREATED!!');
  ref.onDispose(jsonRpcClient.dispose);

  // ref.onDispose(() {
  //   ref.invalidate(_jsonRpcStateProvider(machineUUID));
  // });

  return jsonRpcClient..openChannel();
}

@riverpod
Stream<ClientState> _jsonRpcState(_JsonRpcStateRef ref, String machineUUID, ClientType type) {
  JsonRpcClient activeClient = ref.watch(_jsonRpcClientProvider(machineUUID, type));

  return activeClient.stateStream;
}

@riverpod
JsonRpcClient jrpcClient(JrpcClientRef ref, String machineUUID) {
  var providerToWatch = ref.watch(jrpcClientManagerProvider(machineUUID));
  return ref.watch(providerToWatch);
}

@riverpod
class JrpcClientManager extends _$JrpcClientManager {
  @override
  AutoDisposeProvider<JsonRpcClient> build(String machineUUID) {
    var machine = ref.watch(machineProvider(machineUUID)).valueOrNull;
    if (machine == null) {
      throw MobilerakerException('Machine with UUID "$machineUUID" was not found!');
    }

    if (machine.hasRemoteConnection) _setupHandover(machine).ignore();

    logger.i('Returning LocalClient');
    return _jsonRpcClientProvider(machineUUID, ClientType.local);
  }

  Future<void> _setupHandover(Machine machine) async {
    var clientType = machine.remoteClientType;
    logger.i(
        'A ${clientType.name}-RemoteClient is available. Can do handover in case local client fails! ref:${identityHashCode(ref)}');

    if (!ref.read(remoteConfigProvider).obicoEnabled) {
      logger.i('Obico detected as remoteClientType, but obico is disabled in remoteConfig. Will not setup handover');
      return;
    }

    if (machine.localSsids.isNotEmpty) {
      _setupSmartSwitching(machine, clientType).ignore();
    } else {
      logger.i('[Smart-Switching] Local SSID list is empty. Smart switching disabled');
    }

    var value = await ref.readWhere(
        _jsonRpcStateProvider(machineUUID, ClientType.local), (clientState) => clientState == ClientState.error, false);

    logger.i('Local clientState is $value. Will switch to octo remoteClient. ref:${identityHashCode(ref)}');

    // ref.state = remoteClinet;
    state = _jsonRpcClientProvider(machineUUID, clientType);
    logger.w('Returned ${clientType.name}-RemoteClient');
  }

  Future<void> _setupSmartSwitching(Machine machine, ClientType remoteClientType) async {
    logger.i('[Smart-Switching] Local SSID are set. Can do rapid remote con switching');
    List results = await Future.wait([
      ref.read(networkInfoServiceProvider).getWifiName(),
      ref.read(permissionStatusProvider(Permission.location).future),
      ref.read(permissionServiceStatusProvider(Permission.location).future),
    ]);

    String? wifiName = results[0];
    PermissionStatus? permissionStatus = results[1];
    ServiceStatus? permissionServiceStatus = results[2];

    if (permissionStatus?.isGranted != true) {
      logger.i(
          '[Smart-Switching] WiFi List exists and is not empty, but no location permission. Smart Switching is disabled');
      return;
    }

    if (permissionServiceStatus?.isEnabled != true) {
      logger.i(
          '[Smart-Switching] WiFi List exists and is not empty, but location service is disabled. Smart Switching is disabled');
      return;
    }

    if (machine.localSsids.contains(wifiName)) {
      logger.i('[Smart-Switching] Connected to a WiFi in LocalSsid list of machine. Will use local con');
      return;
    }

    logger.i('[Smart-Switching] Connected to a WiFi NOT in LocalSsid list of machine. Will use remote con');
    state = _jsonRpcClientProvider(machineUUID, remoteClientType);
  }

  refreshCurrentClient() {
    logger.i('Refreshing current client from rpcClientManager');
    var refresh = ref.refresh(state);
    refresh.ensureConnection();
  }
}

@riverpod
Stream<ClientState> jrpcClientState(JrpcClientStateRef ref, String machineUUID) {
  var jsonRpcClient = ref.watch(jrpcClientProvider(machineUUID));

  return ref.watchAsSubject(_jsonRpcStateProvider(machineUUID, jsonRpcClient.clientType));
}

@riverpod
ClientType jrpcClientType(JrpcClientTypeRef ref, String machineUUID) {
  return ref.watch(jrpcClientProvider(machineUUID).select((value) => value.clientType));
}

// final jrpcClientProvider = Provider.autoDispose.family<JsonRpcClient, String>(
//     name: 'jrpcClientProvider', (ref, machineUUID) {
//   var jrpcFallbackService =
//   ref.watch(jrpcFallbackServiceProvider(machineUUID: machineUUID));
//   return jrpcFallbackService.activeClient;
// });
//
// final jrpcClientStateProvider = StreamProvider.autoDispose
//     .family<ClientState, String>(name: 'jrpcClientStateProvider',
//         (ref, machineUUID) {
//       var jrpcFallbackService =
//       ref.watch(jrpcFallbackServiceProvider(machineUUID: machineUUID));
//
//       return jrpcFallbackService.stateStream;
//     });

@riverpod
JsonRpcClient jrpcClientSelected(JrpcClientSelectedRef ref) {
  var machine = ref.watch(selectedMachineProvider).value;
  if (machine == null) {
    throw const MobilerakerException('Machine was null!');
  }
  return ref.watch(jrpcClientProvider(machine.uuid));
}

@riverpod
Stream<ClientState> jrpcClientStateSelected(JrpcClientStateSelectedRef ref) async* {
  try {
    Machine? machine = await ref.watch(selectedMachineProvider.future);
    if (machine == null) return;

    yield* ref.watchAsSubject(jrpcClientStateProvider(machine.uuid));
  } on StateError catch (_) {
// Just catch it. It is expected that the future/where might not complete!
  }
}

@riverpod
Stream<Map<String, dynamic>> jrpcMethodEvent(JrpcMethodEventRef ref, String machineUUID,
    [String method = WILDCARD_METHOD]) {
  StreamController<Map<String, dynamic>> streamController = StreamController.broadcast();
  JsonRpcClient jsonRpcClient = ref.watch(jrpcClientProvider(machineUUID));

  listener(Map<String, dynamic> map) => streamController.add(map);
  jsonRpcClient.addMethodListener(listener, method);

  ref.onDispose(() {
    jsonRpcClient.removeMethodListener(listener, method);
    streamController.close();
  });
  return streamController.stream;
}

extension ClientTypeMachine on Machine {
  // This is not 100% true since it will just check single values first!
  ClientType get remoteClientType {
    if (remoteInterface != null) {
      return ClientType.manual;
    } else if (octoEverywhere != null) {
      return ClientType.octo;
    } else if (obicoTunnel != null) {
      return ClientType.obico;
    } else {
      throw StateError('No remoteClientType available!');
    }
  }
}
