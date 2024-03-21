/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

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
import 'power_service_test.mocks.dart';

@GenerateMocks([JsonRpcClient])
void main() {
  setUpAll(() => setupTestLogger());

  test('get Power API device List', () async {
    String uuid = 'test';
    var mockRpc = MockJsonRpcClient();

    when(mockRpc.addMethodListener(any, 'notify_power_changed')).thenReturn(null);
    when(mockRpc.removeMethodListener(any, 'notify_power_changed')).thenReturn(true);
    when(mockRpc.sendJRpcMethod('machine.device_power.devices'))
        .thenAnswer((realInvocation) async => RpcResponse.fromJson(jsonDecode('''{
          "jsonrpc": "2.0",
          "id":1,
          "result": {
            "devices": [
              {
                "device": "WTF",
                "status": "on",
                "locked_while_printing": true,
                "type": "klipper_device",
                "is_shutdown": false
              }
            ]
          }
        }''')));

    var container = ProviderContainer(overrides: [
      jrpcClientProvider(uuid).overrideWithValue(mockRpc),
    ]);

    var powerService = container.read(powerServiceProvider(uuid));
    List<PowerDevice> list = await powerService.getDeviceList();
    expect(list.isEmpty, false, reason: 'Should return the WTF device!');
    expect(list, [
      const PowerDevice(
          name: 'WTF',
          status: PowerState.on,
          type: PowerDeviceType.klipper_device,
          lockedWhilePrinting: true)
    ]);
  });

  test('Get Power API Device Status', () async {
    String uuid = 'test';
    var mockRpc = MockJsonRpcClient();

    when(mockRpc.addMethodListener(any, 'notify_power_changed')).thenReturn(null);
    when(mockRpc.removeMethodListener(any, 'notify_power_changed')).thenReturn(true);
    when(mockRpc.sendJRpcMethod('machine.device_power.get_device', params: {'device': 'WTF'}))
        .thenAnswer((realInvocation) async => RpcResponse.fromJson(jsonDecode('''{
      "jsonrpc": "2.0",
      "id":1,
      "result": {
        "WTF": "off"
      }
    }''')));

    var container = ProviderContainer(overrides: [
      jrpcClientProvider(uuid).overrideWithValue(mockRpc),
    ]);

    var powerService = container.read(powerServiceProvider(uuid));
    var result = await powerService.getDeviceStatus('WTF');
    expect(result, PowerState.off);
  });

  test('Change Power API Device State', () async {
    String uuid = 'test';
    var mockRpc = MockJsonRpcClient();

    when(mockRpc.addMethodListener(any, 'notify_power_changed')).thenReturn(null);
    when(mockRpc.removeMethodListener(any, 'notify_power_changed')).thenReturn(true);
    when(mockRpc.sendJRpcMethod('machine.device_power.post_device',
            params: {'device': 'WTF', 'action': 'off'}))
        .thenAnswer((realInvocation) async => RpcResponse.fromJson(jsonDecode('''{
          "jsonrpc": "2.0",
          "id":1,
          "result": {
            "WTF": "off"
          }
        }''')));

    var container = ProviderContainer(overrides: [
      jrpcClientProvider(uuid).overrideWithValue(mockRpc),
    ]);

    var powerService = container.read(powerServiceProvider(uuid));
    var result = await powerService.setDeviceStatus('WTF', PowerState.off);
    expect(result, PowerState.off);
  });

  test('Notify Power method listener', () async {
    String uuid = 'test';
    var mockRpc = MockJsonRpcClient();

    ///TODO!!
    when(mockRpc.addMethodListener(any, 'notify_power_changed')).thenReturn(null);
    when(mockRpc.removeMethodListener(any, 'notify_power_changed')).thenReturn(true);
    when(mockRpc.sendJRpcMethod('machine.device_power.post_device',
            params: {'device': 'WTF', 'action': 'off'}))
        .thenAnswer((realInvocation) async => RpcResponse.fromJson(jsonDecode('''{
          "jsonrpc": "2.0",
          "id":1,
          "result": {
            "WTF": "off"
          }
        }''')));

    var j =
        '{"jsonrpc": "2.0", "method": "notify_power_changed", "params": [{"device": "WTF", "status": "off", "locked_while_printing": true, "type": "klipper_device", "is_shutdown": false}]}';

    var container = ProviderContainer(overrides: [
      jrpcClientProvider(uuid).overrideWithValue(mockRpc),
    ]);

    var powerService = container.read(powerServiceProvider(uuid));
    var result = await powerService.setDeviceStatus('WTF', PowerState.off);
    expect(result, PowerState.off);
  });
}
