import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/power/power_device.dart';
import 'package:mobileraker/data/dto/power/power_state.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/moonraker/power_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'power_service_test.mocks.dart';

@GenerateMocks([JsonRpcClient])
void main() {
  test('get Power API device List', () async {
    String uuid = "test";
    var mockRpc = MockJsonRpcClient();

    when(mockRpc.addMethodListener(any, 'notify_power_changed'))
        .thenReturn(null);
    when(mockRpc.sendJRpcMethod('machine.device_power.devices'))
        .thenAnswer((realInvocation) async => RpcResponse(jsonDecode('''{
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
    String uuid = "test";
    var mockRpc = MockJsonRpcClient();

    when(mockRpc.addMethodListener(any, 'notify_power_changed'))
        .thenReturn(null);
    when(mockRpc.sendJRpcMethod('machine.device_power.get_device',
            params: {'device': 'WTF'}))
        .thenAnswer((realInvocation) async => RpcResponse(jsonDecode('''{
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
    String uuid = "test";
    var mockRpc = MockJsonRpcClient();

    when(mockRpc.addMethodListener(any, 'notify_power_changed'))
        .thenReturn(null);
    when(mockRpc.sendJRpcMethod('machine.device_power.post_device',
            params: {'device': 'WTF', 'action': 'off'}))
        .thenAnswer((realInvocation) async => RpcResponse(jsonDecode('''{
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
    String uuid = "test";
    var mockRpc = MockJsonRpcClient();

    ///TODO!!
    when(mockRpc.addMethodListener(any, 'notify_power_changed'))
        .thenReturn(null);
    when(mockRpc.sendJRpcMethod('machine.device_power.post_device',
            params: {'device': 'WTF', 'action': 'off'}))
        .thenAnswer((realInvocation) async => RpcResponse(jsonDecode('''{
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
