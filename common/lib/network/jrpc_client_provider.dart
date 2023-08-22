/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/model/hive/machine.dart';
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

    if (machine.octoEverywhere != null || machine.remoteInterface != null) {
      var clientType = machine.remoteInterface != null ? ClientType.manual : ClientType.octo;

      logger.i(
          'A ${clientType.name}-RemoteClient is available. Can do handover in case local client fails! ref:${identityHashCode(ref)}');
      ref
          .readWhere(_jsonRpcStateProvider(machineUUID, ClientType.local),
              (clientState) => clientState == ClientState.error, false)
          .then((value) {
        logger.i(
            'Local clientState is $value. Will switch to octo remoteClient. ref:${identityHashCode(ref)}');

        // ref.state = remoteClinet;
        state = _jsonRpcClientProvider(machineUUID, clientType);
        logger.w('Returned ${clientType.name}-RemoteClient');
      }).ignore();
    }

    logger.i('Returning LocalClient');
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
