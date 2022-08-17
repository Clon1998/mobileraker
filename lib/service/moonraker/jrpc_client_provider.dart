import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/exceptions.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/util/ref_extension.dart';
import 'package:rxdart/rxdart.dart';

final jrpcClientProvider = Provider.autoDispose.family<JsonRpcClient, String>(
    name: 'jrpcClientProvider', (ref, machineUUID) {
  var machine = Hive.box<Machine>('printers').get(machineUUID);
  if (machine == null) {
    throw MobilerakerException(
        'Machine with UUID "$machineUUID" was not found!');
  }
  // // logger.wtf('JRPC creating for: $machineUUID## ${identityHashCode(machine)}');
  // ref.onDispose(() {
  //   logger
  //       .wtf('JRPC disposing for: $machineUUID## ${identityHashCode(machine)}');
  // });
  // ref.onCancel(() {
  //   logger
  //       .wtf('JRPC onCancel for: $machineUUID## ${identityHashCode(machine)}');
  // });
  var jsonRpcClient = JsonRpcClient(
    machine.wsUrl,
  );
  ref.onDispose(jsonRpcClient.dispose);
  jsonRpcClient.openChannel();
  return jsonRpcClient;
});

final jrpcClientStateProvider = StreamProvider.autoDispose
    .family<ClientState, String>(name: 'jrpcClientStateProvider',
        (ref, machineUUID) {
  // logger.wtf('jrpcClientStateProvider creating for: $machineUUID');
  // ref.onDispose(() {
  //   logger.wtf('jrpcClientStateProvider disposing for: $machineUUID}');
  // });
  return ref.watch(jrpcClientProvider(machineUUID)).stateStream;
});

final jrpcClientSelectedProvider = Provider.autoDispose<JsonRpcClient>(
    name: 'jrpcClientSelectedProvider', (ref) {
  var machine = ref.watch(selectedMachineProvider).value;
  if (machine == null) {
    throw const MobilerakerException('Machine was null!');
  }
  return ref.watch(jrpcClientProvider(machine.uuid));
});

final jrpcClientStateSelectedProvider = StreamProvider.autoDispose<ClientState>(
    name: 'jrpcClientStateSelectedProvider', (ref) async* {
  var machine = await ref.watchWhereNotNull(selectedMachineProvider);
  yield* ref.watch(jrpcClientStateProvider(machine.uuid).stream);
});
