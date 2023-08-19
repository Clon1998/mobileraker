/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/hive/octoeverywhere.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
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

  JsonRpcClient jsonRpcClient;
  if (type == ClientType.local) {
    jsonRpcClient = JsonRpcClientBuilder.fromMachine(machine).build();
  } else if (type == ClientType.octo) {
    if (machine.octoEverywhere == null) {
      throw ArgumentError('The provided machine,$machineUUID does not offer OctoEverywhere');
    }
    jsonRpcClient = JsonRpcClientBuilder.fromOcto(machine).build();
  } else {
    throw ArgumentError('Unknown Client type $type');
  }

  logger.i('JsonRpcClient (${jsonRpcClient.uri} , $type) CREATED!!');
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

    OctoEverywhere? octoEverywhere = machine.octoEverywhere;
    if (octoEverywhere == null) {
      logger.i(
          'No OE config was found! Will only rely on local client. ref:${identityHashCode(ref)}');
      return _jsonRpcClientProvider(machineUUID, ClientType.local);
    }
    logger.i(
        'An OE config is available. Can do handover in case local client fails! ref:${identityHashCode(ref)}');

    ref
        .readWhere(_jsonRpcStateProvider(machineUUID, ClientType.local),
            (clientState) => clientState == ClientState.error, false)
        .then((value) {
      var remoteClinet = logger.i(
          'Local clientState is $value. Will switch to remoteClient. ref:${identityHashCode(ref)}');

      // ref.state = remoteClinet;
      state = _jsonRpcClientProvider(machineUUID, ClientType.octo);
      logger.w('Returned RemoteClient');
    });
    logger.w('Returning LocalClient');
    return _jsonRpcClientProvider(machineUUID, ClientType.local);
  }

  refreshCurrentClient() {
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
    Machine machine = await ref.watchWhereNotNull(selectedMachineProvider);
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
