/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/dto/server/klipper_system_info.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/dto/server/service_status.dart';
import '../../network/jrpc_client_provider.dart';
import '../selected_machine_service.dart';

part 'klipper_system_service.g.dart';

/// Shorthand to get the status of a service
@riverpod
Future<ServiceStatus> systemServiceStatus(SystemServiceStatusRef ref, String machineUUID, String service) async {
  var serviceState =
      await ref.watch(klipperSystemInfoProvider(machineUUID).selectAsync((data) => data.serviceState[service]));

  if (serviceState == null) {
    throw ArgumentError('Service "$service" not found in KlipperSystemInfo');
  }
  return serviceState;
}

@riverpod
Future<KlipperSystemInfo> klipperSystemInfo(KlipperSystemInfoRef ref, String machineUUID) async {
  var client = ref.watch(jrpcClientProvider(machineUUID));

  var response = await client.sendJRpcMethod('machine.system_info');

  // https://moonraker.readthedocs.io/en/latest/web_api/#service-state-changed
  ref.listen(jrpcMethodEventProvider(machineUUID, 'notify_service_state_changed'), (previous, next) {
    if (next.isLoading) return;
    if (next.hasError) return;

    var rawMessage = next.requireValue;
    /*
    [
        {
            "klipper": {
                "active_state": "inactive",
                "sub_state": "dead"
            }
        }
    ]

     */
    Map<String, dynamic> rawServiceUpdates = rawMessage['params'][0];
    var changedServices = rawServiceUpdates
        .map((k, e) => MapEntry(k, ServiceStatus.fromJson({'name': k, ...(e as Map<String, dynamic>)})));

    ref.state = ref.state.whenData(
        (value) => value.copyWith(serviceState: Map.unmodifiable({...value.serviceState, ...changedServices})));
  });

  var json = response.result['system_info'];
  KlipperSystemInfo info = KlipperSystemInfo.fromJson(json);
  return info;
}

@riverpod
Stream<KlipperSystemInfo> selectedKlipperSystemInfo(SelectedKlipperSystemInfoRef ref) async* {
  ref.keepAliveFor();
  try {
    var machine = await ref.watch(selectedMachineProvider.future);
    if (machine == null) return;

    yield await ref.watch(klipperSystemInfoProvider(machine.uuid).future);
  } on StateError catch (_) {
    // Just catch it. It is expected that the future/where might not complete!
  }
}
