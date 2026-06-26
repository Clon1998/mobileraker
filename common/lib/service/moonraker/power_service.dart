/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/power/power_device.dart';
import 'package:common/data/enums/power_state_enum.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'power_service.g.dart';

@riverpod
class PowerDevices extends _$PowerDevices {
  JsonRpcClient get _jrpcClient => ref.read(jrpcClientProvider(machineUUID));

  @override
  Future<List<PowerDevice>> build(String machineUUID) async {
    await ref.watch(jrpcClientStateProvider(machineUUID).future);

    ref.listen(jrpcMethodEventProvider(machineUUID, 'notify_power_changed'), (_, next) {
      if (!next.hasValue) return;
      _onPowerChanged(next.value!);
    });

    return _fetchDevices();
  }

  Future<List<PowerDevice>> _fetchDevices() async {
    talker.info('[PowerDevicesNotifier($machineUUID)] Fetching power devices...');
    final resp = await _jrpcClient.sendJRpcMethod('machine.device_power.devices');
    final raw = List<Map<String, dynamic>>.from(resp.result['devices'] as List);
    return List.generate(raw.length, (i) => PowerDevice.fromJson(raw[i]), growable: false);
  }

  void _onPowerChanged(Map<String, dynamic> rawMessage) {
    final raw = List<Map<String, dynamic>>.from(rawMessage['params'] as List);
    final parsed = List.generate(raw.length, (i) => PowerDevice.fromJson(raw[i]), growable: false);
    final current = state.value;
    if (current == null || current.isEmpty) return;

    state = AsyncData(
      current
          .map((e) => parsed.firstWhere((p) => p.name == e.name, orElse: () => e))
          .toList(growable: false),
    );
  }

  Future<PowerState> setDeviceStatus(String deviceName, PowerState powerState) async {
    try {
      talker.info('[PowerDevicesNotifier($machineUUID)] Setting device "$deviceName" → $powerState');
      final resp = await _jrpcClient.sendJRpcMethod(
        'machine.device_power.post_device',
        params: {'device': deviceName, 'action': powerState.name},
      );
      return PowerState.tryFromJson(resp.result[deviceName]) ?? PowerState.off;
    } on JRpcError catch (e, s) {
      talker.error('[PowerDevicesNotifier($machineUUID)] Error setting device "$deviceName" state!', e, s);
      return PowerState.off;
    }
  }

  Future<PowerState> getDeviceStatus(String deviceName) async {
    try {
      talker.info('[PowerDevicesNotifier($machineUUID)] Fetching device "$deviceName" status');
      final resp = await _jrpcClient.sendJRpcMethod(
        'machine.device_power.get_device',
        params: {'device': deviceName},
      );
      return PowerState.tryFromJson(resp.result[deviceName]) ?? PowerState.off;
    } on JRpcError catch (e, s) {
      talker.error('[PowerDevicesNotifier($machineUUID)] Error fetching device "$deviceName" state!', e, s);
      return PowerState.off;
    }
  }
}
