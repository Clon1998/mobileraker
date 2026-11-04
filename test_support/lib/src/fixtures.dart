/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/files/folder.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/firebase/remote_config.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart' show Override;

import 'fake_json_rpc_client.dart';

/// Test data. Builders take the fields tests usually care about; everything else has a plain default.
abstract final class Fixtures {
  static Machine machine({String uuid = 'm1', String name = 'Voron'}) =>
      Machine(name: name, httpUri: Uri.parse('http://$name.local'.toLowerCase()), uuid: uuid);

  static Folder folder(String name, {String parentPath = 'gcodes'}) =>
      Folder(parentPath: parentPath, modified: 1700000000, name: name, size: 0);

  static GCodeFile gcode(
    String name, {
    String parentPath = 'gcodes',
    int size = 1024 * 1024,
    double? estimatedTime = 3600,
    double modified = 1700000000,
  }) => GCodeFile(name: name, parentPath: parentPath, modified: modified, size: size, estimatedTime: estimatedTime);
}

/// Overrides for a selected machine whose websocket is connected (with [client], a [FakeJsonRpcClient] by default).
List<Override> connectedMachineOverrides(Machine machine, {FakeJsonRpcClient? client}) {
  final rpc = client ?? FakeJsonRpcClient();
  return [
    selectedMachineProvider.overrideWithValue(AsyncData(machine)),
    machineProvider(machine.uuid).overrideWithValue(AsyncData(machine)),
    jrpcClientProvider(machine.uuid).overrideWithValue(rpc),
    jrpcClientStateProvider(machine.uuid).overrideWithValue(const AsyncData(ClientState.connected)),
    jrpcClientTypeProvider(machine.uuid).overrideWithValue(rpc.clientType),
  ];
}

/// Remote config without Firebase: the given values, otherwise 0 / false / ''.
List<Override> remoteConfigOverrides({
  Map<String, int> ints = const {},
  Map<String, bool> bools = const {},
  Map<String, String> strings = const {},
}) => [
  remoteConfigIntProvider.overrideWith((ref, key) => ints[key] ?? 0),
  remoteConfigBoolProvider.overrideWith((ref, key) => bools[key] ?? false),
  remoteConfigStringProvider.overrideWith((ref, key) => strings[key] ?? ''),
];
