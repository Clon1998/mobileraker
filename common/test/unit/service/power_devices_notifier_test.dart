/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:convert';

import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/data/dto/power/power_device.dart';
import 'package:common/data/enums/power_state_enum.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/moonraker/power_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../test_utils.dart';
import 'power_devices_notifier_test.mocks.dart';

@GenerateMocks([JsonRpcClient])
void main() {
  setUpAll(() {
    setupTestLogger();
    provideDummy<RpcResponse>(RpcResponse.fromJson(jsonDecode('{"jsonrpc":"2.0","id":1,"result":{}}')));
  });

  const uuid = 'test-machine';

  // Build responses directly to avoid unnecessary JSON round-trips.
  RpcResponse devicesResponse(List<Map<String, dynamic>> devices) =>
      RpcResponse(jsonrpc: '2.0', id: 1, result: {'devices': devices});

  RpcResponse postDeviceResponse(String device, String status) =>
      RpcResponse(jsonrpc: '2.0', id: 1, result: {device: status});

  RpcResponse getDeviceResponse(String device, String status) =>
      RpcResponse(jsonrpc: '2.0', id: 1, result: {device: status});

  const wtfDeviceOn = {
    'device': 'WTF',
    'status': 'on',
    'locked_while_printing': true,
    'type': 'klipper_device',
    'is_shutdown': false,
  };

  const wtfDeviceOff = {
    'device': 'WTF',
    'status': 'off',
    'locked_while_printing': true,
    'type': 'klipper_device',
    'is_shutdown': false,
  };

  ProviderContainer makeContainer(
    MockJsonRpcClient mockRpc, {
    StreamController<Map<String, dynamic>>? powerChangedCtrl,
  }) {
    final container = ProviderContainer.test(overrides: [
      jrpcClientProvider(uuid).overrideWithValue(mockRpc),
      jrpcClientStateProvider(uuid).overrideWith((ref) async => ClientState.connected),
      jrpcMethodEventProvider(uuid, 'notify_power_changed')
          .overrideWith(
              (ref) => (powerChangedCtrl ?? StreamController<Map<String, dynamic>>.broadcast()).stream),
    ]);
    return container;
  }

  test('initial build fetches devices when JRPC is connected', () async {
    final mockRpc = MockJsonRpcClient();

    when(mockRpc.sendJRpcMethod('machine.device_power.devices'))
        .thenAnswer((_) async => devicesResponse([wtfDeviceOn]));

    final container = makeContainer(mockRpc);
    final devices = await container.read(powerDevicesProvider(uuid).future);

    expect(devices, hasLength(1));
    expect(devices.first, const PowerDevice(
      name: 'WTF',
      status: PowerState.on,
      type: PowerDeviceType.klipper_device,
      lockedWhilePrinting: true,
    ));
  });

  test('initial build returns empty list when no devices configured', () async {
    final mockRpc = MockJsonRpcClient();

    when(mockRpc.sendJRpcMethod('machine.device_power.devices'))
        .thenAnswer((_) async => devicesResponse([]));

    final container = makeContainer(mockRpc);
    final devices = await container.read(powerDevicesProvider(uuid).future);

    expect(devices, isEmpty);
  });

  test('notify_power_changed merges updated device state into current list', () async {
    final mockRpc = MockJsonRpcClient();
    final powerChangedCtrl = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(powerChangedCtrl.close);

    when(mockRpc.sendJRpcMethod('machine.device_power.devices'))
        .thenAnswer((_) async => devicesResponse([wtfDeviceOn]));

    final container = makeContainer(mockRpc, powerChangedCtrl: powerChangedCtrl);
    // Keep alive so auto-dispose doesn't remove the provider between reads
    final sub = container.listen(powerDevicesProvider(uuid), (_, __) {});
    addTearDown(sub.close);

    await container.read(powerDevicesProvider(uuid).future);

    // Simulate Moonraker pushing a state change: WTF → off
    powerChangedCtrl.add({'params': [wtfDeviceOff]});
    await pumpEventQueue();

    final updated = container.read(powerDevicesProvider(uuid)).value;
    expect(updated, hasLength(1));
    expect(updated!.first.status, PowerState.off);
  });

  test('notify_power_changed is a no-op when current device list is empty', () async {
    final mockRpc = MockJsonRpcClient();
    final powerChangedCtrl = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(powerChangedCtrl.close);

    when(mockRpc.sendJRpcMethod('machine.device_power.devices'))
        .thenAnswer((_) async => devicesResponse([]));

    final container = makeContainer(mockRpc, powerChangedCtrl: powerChangedCtrl);
    final sub = container.listen(powerDevicesProvider(uuid), (_, __) {});
    addTearDown(sub.close);

    await container.read(powerDevicesProvider(uuid).future);

    // Event arrives but current state is empty — should be ignored
    powerChangedCtrl.add({'params': [wtfDeviceOn]});
    await pumpEventQueue();

    final state = container.read(powerDevicesProvider(uuid)).value;
    expect(state, isEmpty);
  });

  test('setDeviceStatus sends correct JRPC call and returns new state', () async {
    final mockRpc = MockJsonRpcClient();

    when(mockRpc.sendJRpcMethod('machine.device_power.devices'))
        .thenAnswer((_) async => devicesResponse([wtfDeviceOn]));
    when(mockRpc.sendJRpcMethod('machine.device_power.post_device',
            params: {'device': 'WTF', 'action': 'off'}))
        .thenAnswer((_) async => postDeviceResponse('WTF', 'off'));

    final container = makeContainer(mockRpc);
    await container.read(powerDevicesProvider(uuid).future);

    final result =
        await container.read(powerDevicesProvider(uuid).notifier).setDeviceStatus('WTF', PowerState.off);

    expect(result, PowerState.off);
    verify(mockRpc.sendJRpcMethod('machine.device_power.post_device',
            params: {'device': 'WTF', 'action': 'off'}))
        .called(1);
  });

  test('getDeviceStatus sends correct JRPC call and returns current state', () async {
    final mockRpc = MockJsonRpcClient();

    when(mockRpc.sendJRpcMethod('machine.device_power.devices'))
        .thenAnswer((_) async => devicesResponse([wtfDeviceOn]));
    when(mockRpc.sendJRpcMethod('machine.device_power.get_device', params: {'device': 'WTF'}))
        .thenAnswer((_) async => getDeviceResponse('WTF', 'on'));

    final container = makeContainer(mockRpc);
    await container.read(powerDevicesProvider(uuid).future);

    final result =
        await container.read(powerDevicesProvider(uuid).notifier).getDeviceStatus('WTF');

    expect(result, PowerState.on);
    verify(mockRpc.sendJRpcMethod('machine.device_power.get_device', params: {'device': 'WTF'})).called(1);
  });

  test('provider rebuilds and re-fetches on invalidation (simulates reconnect)', () async {
    final mockRpc = MockJsonRpcClient();
    var callCount = 0;

    when(mockRpc.sendJRpcMethod('machine.device_power.devices')).thenAnswer((_) async {
      callCount++;
      return devicesResponse([wtfDeviceOn]);
    });

    final container = makeContainer(mockRpc);
    // Keep alive so invalidation triggers an actual rebuild with listeners
    final sub = container.listen(powerDevicesProvider(uuid), (_, __) {});
    addTearDown(sub.close);

    await container.read(powerDevicesProvider(uuid).future);
    expect(callCount, 1);

    container.invalidate(powerDevicesProvider(uuid));
    await container.read(powerDevicesProvider(uuid).future);
    expect(callCount, 2);
  });
}
