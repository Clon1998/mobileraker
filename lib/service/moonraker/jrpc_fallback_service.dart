import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/hive/octoeverywhere.dart';
import 'package:mobileraker/exceptions.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:mobileraker/util/ref_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'jrpc_fallback_service.g.dart';

@riverpod
JsonRpcClient _jsonRpcClient(_JsonRpcClientRef ref, Machine machine) {
  var jsonRpcClient = JsonRpcClientBuilder.fromMachine(machine).build();
  ref.onDispose(jsonRpcClient.dispose);
  return jsonRpcClient..openChannel();
}

var _jsonRpcStateProvider = StreamProvider.autoDispose
    .family<ClientState, JsonRpcClient>(name: '_jsonRpcStateProvider',
        (ref, rpcClient) {
  return rpcClient.stateStream;
});

@riverpod
JsonRpcClient _octoJsonRpcClient(
    _OctoJsonRpcClientRef ref, OctoEverywhere octoEverywhere) {
  var octoClient = JsonRpcClientBuilder.fromOcto(octoEverywhere).build();
  // logger.w('Bearer: ${octoEverywhere.authBearerToken}');
  ref.onDispose(octoClient.dispose);
  return octoClient..openChannel();
}

@riverpod
JsonRpcClient activeClient(ActiveClientRef ref, String machineUUID) {
  var machine = ref.watch(machineProvider(machineUUID)).valueOrFullNull;
  if (machine == null) {
    throw MobilerakerException(
        'Machine with UUID "$machineUUID" was not found!');
  }

  JsonRpcClient localClient = ref.watch(_jsonRpcClientProvider(machine));
  ref.listen<AsyncValue<ClientState>>(_jsonRpcStateProvider(localClient),
      (previous, AsyncValue<ClientState> next) {
    next.when(
      data: (d) async {
        if (d == ClientState.error) {
          logger.wtf('Local client failed... trying remote one');

          OctoEverywhere? octoEverywhere = machine.octoEverywhere;
          if (octoEverywhere == null) {
            logger.i('No remote client configured... cant do handover!');
            return;
          }
          JsonRpcClient remoteClient =
              ref.watch(_octoJsonRpcClientProvider(octoEverywhere));
          ref.state = remoteClient;
        }
      },
      error: (e, s) {},
      loading: () {},
    );
  }, fireImmediately: true);

  return localClient;
}

@riverpod
ClientType activeClientType(ActiveClientTypeRef ref, String machineUUID) {
  return ref.watch(
      activeClientProvider(machineUUID).select((value) => value.clientType));
}

final activeClientStateProvider = StreamProvider.autoDispose
    .family<ClientState, String>(name: 'activeClientStateProvider',
        (ref, machineUUID) async* {
  JsonRpcClient activeClient = ref.watch(activeClientProvider(machineUUID));

  StreamController<ClientState> sc = StreamController<ClientState>();
  ref.onDispose(() {
    if (!sc.isClosed) {
      sc.close();
    }
  });
  ref.listen<AsyncValue<ClientState>>(_jsonRpcStateProvider(activeClient),
      (previous, next) {
    next.when(
        data: (data) => sc.add(data),
        error: (err, st) => sc.addError(err, st),
        loading: () {
          if (previous != null) ref.invalidateSelf();
        });
  }, fireImmediately: true);

  yield* sc.stream;
});
