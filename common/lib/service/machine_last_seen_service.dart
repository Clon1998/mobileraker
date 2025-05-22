/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/util/logger.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../network/json_rpc_client.dart';

part 'machine_last_seen_service.g.dart';

@riverpod
MachineLastSeenService machineLastSeenService(Ref ref, String machineUUID) {
  ref.keepAlive();
  return MachineLastSeenService(ref, machineUUID);
}

@riverpod
DateTime? machineLastSeen(Ref ref, String machineUUID) =>
    ref.watch(machineLastSeenServiceProvider(machineUUID)).getLastSeen();

class MachineLastSeenService {
  const MachineLastSeenService(this.ref, this.machineUUID);

  final Ref ref;
  final String machineUUID;

  MachineService get machineService => ref.read(machineServiceProvider);

  SettingService get _settingService => ref.read(settingServiceProvider);

  KeyValueStoreKey get lastSeenKey => CompositeKey.keyWithString(UtilityKeys.machineLastSeen, machineUUID);

  void trackLastSeen() {
    talker.info('machineLastSeenService($machineUUID): machine with UUID $machineUUID is tracking last seen');
    ref.listen(jrpcClientStateProvider(machineUUID), (previous, next) async {
      try {
        talker.info(
            'machineLastSeenService($machineUUID): machine with UUID $machineUUID changed state: $previous ${next}');
        if (next.valueOrNull == ClientState.connected || next.valueOrNull == ClientState.connected) {
          talker.info(
              'machineLastSeenService($machineUUID): machine with UUID $machineUUID is connected, will update lastSeen');
          updateLastSeen(DateTime.now());
        }
      } catch (e, s) {
        talker.error('machineLastSeenService($machineUUID): Unexpected error in machineLastSeenService: $e', s);
      }
    }, fireImmediately: true);
  }

  DateTime? getLastSeen() {
    DateTime? lastSeen = _settingService.read(lastSeenKey, null);
    talker.info('machineLastSeenService($machineUUID): machine with UUID $machineUUID last seen time: $lastSeen');
    return lastSeen;
  }

  void updateLastSeen(DateTime now) {
    _settingService.write(lastSeenKey, now);
    talker.info('machineLastSeenService($machineUUID): machine with UUID $machineUUID last seen time updated to $now');
  }
}
