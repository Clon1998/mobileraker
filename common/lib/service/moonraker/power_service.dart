/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/extensions/uri_extension.dart';
import 'package:common/util/logger.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/dto/power/power_device.dart';
import '../../data/enums/power_state_enum.dart';
import '../../network/jrpc_client_provider.dart';

part 'power_service.g.dart';

@riverpod
PowerService powerService(PowerServiceRef ref, String machineUUID) {
  var jsonRpcClient = ref.watch(jrpcClientProvider(machineUUID));
  return PowerService(ref, jsonRpcClient, machineUUID);
}

@riverpod
Stream<List<PowerDevice>> powerDevices(PowerDevicesRef ref, String machineUUID) {
  return ref.watch(powerServiceProvider(machineUUID)).devices;
}


/// The PowerService handels interactions with Moonraker's Power API
/// For more information check out
/// 1. https://moonraker.readthedocs.io/en/latest/web_api/#power-apis
class PowerService {
  PowerService(AutoDisposeRef ref, this._jRpcClient, String machineUUID) {
    ref.onDispose(dispose);
    _jRpcClient.addMethodListener(_onPowerChanged, 'notify_power_changed');
    ref.listen(jrpcClientStateProvider(machineUUID), (previous, next) {
      switch (next.valueOrNull) {
        case ClientState.connected:
          _init();
          break;
        default:
      }
    }, fireImmediately: true);
  }

  final StreamController<List<PowerDevice>> _devicesStreamCtler = StreamController();

  List<PowerDevice>? __current;

  set _current(List<PowerDevice> p) {
    __current = p;
    if (!_devicesStreamCtler.isClosed) _devicesStreamCtler.add(p);
  }

  Stream<List<PowerDevice>> get devices => _devicesStreamCtler.stream;

  final JsonRpcClient _jRpcClient;

  /// https://moonraker.readthedocs.io/en/latest/web_api/#get-device-list
  Future<List<PowerDevice>> getDeviceList() async {
    logger.i('[PowerService ${_jRpcClient.clientType}@${_jRpcClient.uri.obfuscate()}] Fetching [power] devices!');
    RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod('machine.device_power.devices');
    List<Map<String, dynamic>> devices = rpcResponse.result['devices'].cast<Map<String, dynamic>>();
    return List.generate(devices.length, (index) => PowerDevice.fromJson(devices[index]), growable: false);
  }

  /// https://moonraker.readthedocs.io/en/latest/web_api/#set-device-state
  Future<PowerState> setDeviceStatus(String deviceName, PowerState state) async {
    try {
      RpcResponse rpcResponse = await _jRpcClient
          .sendJRpcMethod('machine.device_power.post_device', params: {'device': deviceName, 'action': state.name});
      logger.i(
          '[PowerService ${_jRpcClient.clientType}@${_jRpcClient.uri.obfuscate()}] Setting [power] device "$deviceName" -> $state!');

      Map<String, dynamic> result = rpcResponse.result;
      return PowerState.tryFromJson(result[deviceName]) ?? PowerState.off;
    } on JRpcError catch (e, s) {
      logger.e(
          '[PowerService ${_jRpcClient.clientType}@${_jRpcClient.uri.obfuscate()}] Error while trying to set state of [power] device with name "$deviceName"!',
          e,
          s);
      return PowerState.off;
    }
  }

  /// https://moonraker.readthedocs.io/en/latest/web_api/#get-device-status
  Future<PowerState> getDeviceStatus(String deviceName) async {
    try {
      RpcResponse rpcResponse =
          await _jRpcClient.sendJRpcMethod('machine.device_power.get_device', params: {'device': deviceName});
      logger.i(
          '[PowerService ${_jRpcClient.clientType}@${_jRpcClient.uri.obfuscate()}] Fetching [power] device state of "$deviceName" !');

      Map<String, dynamic> result = rpcResponse.result;
      return PowerState.tryFromJson(result[deviceName]) ?? PowerState.off;
    } on JRpcError catch (e, s) {
      logger.e(
          '[PowerService ${_jRpcClient.clientType}@${_jRpcClient.uri.obfuscate()}] Error while trying to fetch state of [power] device with name "$deviceName"!',
          e,
          s);
      return PowerState.off;
    }
  }

  _init() async {
    try {
      var devices = await getDeviceList();
      _current = devices;
    } on JRpcError catch (e, s) {
      logger.e(
          '[PowerService ${_jRpcClient.clientType}@${_jRpcClient.uri.obfuscate()}] Error while trying to fetch [power] devices!',
          e);
      if (!_devicesStreamCtler.isClosed) {
        _devicesStreamCtler.addError(e, s);
      }
    }
  }

  _onPowerChanged(Map<String, dynamic> rawMessage) {
    List<Map<String, dynamic>> devices = rawMessage['params'].cast<Map<String, dynamic>>();

    List<PowerDevice> parsed =
        List.generate(devices.length, (index) => PowerDevice.fromJson(devices[index]), growable: false);
    if (__current == null || __current!.isEmpty) return;

    var result = __current!.map((e) {
      return parsed.firstWhere((p) => p.name == e.name, orElse: () => e);
    }).toList(growable: false);

    logger
        .v('[PowerService ${_jRpcClient.clientType}@${_jRpcClient.uri.obfuscate()}] Updated powerDevices to: $result');
    _current = result;
  }

  dispose() {
    _jRpcClient.removeMethodListener(_onPowerChanged, 'notify_power_changed');
    _devicesStreamCtler.close();
  }
}
