/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/hive/octoeverywhere.dart';
import 'package:mobileraker/exceptions.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:mobileraker/util/ref_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'jrpc_client_provider.g.dart';

@riverpod
JsonRpcClient _jsonRpcClient(
    _JsonRpcClientRef ref, String machineUUID, ClientType type) {
  var machine = ref.watch(machineProvider(machineUUID)).valueOrFullNull;

  if (machine == null) {
    throw ArgumentError('Provided machine. $machineUUID, was null?');
  }

  JsonRpcClient jsonRpcClient;
  if (type == ClientType.local) {
    jsonRpcClient = JsonRpcClientBuilder.fromMachine(machine).build();
  } else if (type == ClientType.octo) {
    if (machine.octoEverywhere == null) {
      throw ArgumentError(
          'The provided machine,$machineUUID does not offer OctoEverywhere');
    }
    jsonRpcClient = JsonRpcClientBuilder.fromOcto(machine).build();
  } else {
    throw ArgumentError('Unknown Client type $type');
  }

  ref.onDispose(jsonRpcClient.dispose);
  // ref.onDispose(() {
  //   ref.invalidate(_jsonRpcStateProvider(machineUUID));
  // });

  return jsonRpcClient..openChannel();
}

@riverpod
Stream<ClientState> _jsonRpcState(
    _JsonRpcStateRef ref, String machineUUID, ClientType type) {
  JsonRpcClient activeClient =
      ref.watch(_jsonRpcClientProvider(machineUUID, type));

  return activeClient.stateStream;
}

@riverpod
JsonRpcClient jrpcClient(JrpcClientRef ref, String machineUUID) {
  var machine = ref.watch(machineProvider(machineUUID)).valueOrFullNull;
  if (machine == null) {
    throw MobilerakerException(
        'Machine with UUID "$machineUUID" was not found!');
  }
  JsonRpcClient localClient = ref
      .watch(_jsonRpcClientProvider(machineUUID, ClientType.local))
    ..ensureConnection();

  OctoEverywhere? octoEverywhere = machine.octoEverywhere;
  if (octoEverywhere == null) {
    logger.i(
        'No remote client configured... cant do handover! ref:${identityHashCode(ref)}');
    return localClient;
  }
  // This section needs to be run if the local client provider was already present
  if (localClient.curState == ClientState.error) {
    logger.i(
        'Local client already is errored? Returning remote one... ref:${identityHashCode(ref)}');
    return ref.watch(_jsonRpcClientProvider(machineUUID, ClientType.octo));
  }
  // Here we register a listner that can wait for the loal client to switch to remote one!
  late ProviderSubscription sub;
  sub = ref.listen<AsyncValue<ClientState>>(
      _jsonRpcStateProvider(machineUUID, ClientType.local),
      (previous, AsyncValue<ClientState> next) {
    next.whenData(
      (d) async {
        if (d == ClientState.error) {

          var remoteClinet =
              ref.watch(_jsonRpcClientProvider(machineUUID, ClientType.octo));

          logger.i(
              'Returning remote client... ref:${identityHashCode(ref)}, remoteclient:${identityHashCode(remoteClinet)}');
          ref.state = remoteClinet;
        }
      },
    );
  });
  return localClient;
}

@riverpod
Stream<ClientState> jrpcClientState(
    JrpcClientStateRef ref, String machineUUID) {
  var jsonRpcClient = ref.watch(jrpcClientProvider(machineUUID));


  StreamController<ClientState> sc = StreamController<ClientState>();

  ref.listen<AsyncValue<ClientState>>(
      _jsonRpcStateProvider(machineUUID, jsonRpcClient.clientType),
      (previous, next) {
    if (sc.isClosed) {
      ref.invalidateSelf();
      return;
    }
    next.when(
        data: (data) => sc.add(data),
        error: (err, st) => sc.addError(err, st),
        loading: () {
          if (previous != null) ref.invalidateSelf();
        });
  }, fireImmediately: true);

  ref.onDispose(() {
    if (!sc.isClosed) {
      sc.close();
    }
  });
  return sc.stream;
}

@riverpod
ClientType jrpcClientType(JrpcClientTypeRef ref, String machineUUID) {
  return ref.watch(
      jrpcClientProvider(machineUUID).select((value) => value.clientType));
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
    StreamController<ClientState> sc = StreamController<ClientState>();
    ref.onDispose(() {
      if (!sc.isClosed) {
        sc.close();
      }
    });

    ref.listen<AsyncValue<ClientState>>(jrpcClientStateProvider(machine.uuid),
            (previous, next) {
          next.when(
              data: (data) => sc.add(data),
              error: (err, st) => sc.addError(err, st),
              loading: () {
                if (previous != null) ref.invalidateSelf();
              });
        }, fireImmediately: true);

    yield* sc.stream;
  } on StateError catch (_) {
// Just catch it. It is expected that the future/where might not complete!
  }
}
