/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/dto/history/history_params.dart';
import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/extensions/uri_extension.dart';
import 'package:common/util/logger.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/dto/history/historical_print_job.dart';
import '../../network/jrpc_client_provider.dart';

part 'history_service.g.dart';

@riverpod
HistoryService historyService(Ref ref, String machineUUID) {
  final jsonRpcClient = ref.watch(jrpcClientProvider(machineUUID));
  return HistoryService(ref, jsonRpcClient, machineUUID);
}

@riverpod
Future<List<HistoricalPrintJob>> jobHistory(Ref ref, String machineUUID, HistoryParams? params) async {
  final service = ref.watch(historyServiceProvider(machineUUID));

  ref.listen(jrpcMethodEventProvider(machineUUID, 'notify_history_changed'), (previous, next) {
    if (next.isLoading) return;
    if (next.hasError) return;

    ref.invalidateSelf();
  });

  return service.getJobList(params);
}

@riverpod
Future<HistoricalPrintJob?> lastJob(Ref ref, String machineUUID) async {
  ref.keepAliveFor(); // ToDo do NOT use keepAlive!
  final list = await ref.watch(jobHistoryProvider(machineUUID, null).future);
  return list.firstOrNull;
}

/// The HistoryService handels interactions with Moonraker's History API
/// For more information check out
/// 1.https://moonraker.readthedocs.io/en/latest/web_api/#history-apis
class HistoryService {
  HistoryService(Ref ref, this._jRpcClient, String machineUUID) {
    ref.onDispose(dispose);
    // _jRpcClient.addMethodListener(_onPowerChanged, 'notify_power_changed');
    // ref.listen(jrpcClientStateProvider(machineUUID), (previous, next) {
    //   switch (next.valueOrNull) {
    //     case ClientState.connected:
    //       _init();
    //       break;
    //     default:
    //   }
    // }, fireImmediately: true);
  }

  final JsonRpcClient _jRpcClient;

  /// https://moonraker.readthedocs.io/en/latest/external_api/history/#get-job-list
  Future<List<HistoricalPrintJob>> getJobList(HistoryParams? params) async {
    try {
      talker.info('[HistoryService ${_jRpcClient.clientType}@${_jRpcClient.uri.obfuscate()}] Fetching job list!');
      RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod('server.history.list', params: params?.toJson());
      talker.info('[HistoryService ${_jRpcClient.clientType}@${_jRpcClient.uri.obfuscate()}] Job list fetched!');
      talker.info(rpcResponse.result);

      List<Map<String, dynamic>> devices = rpcResponse.result['jobs'].cast<Map<String, dynamic>>();
      return List.generate(devices.length, (index) => HistoricalPrintJob.fromJson(devices[index]), growable: false);
    } on JRpcError catch (e, s) {
      talker.error('Error fetching job list', e, s);
      rethrow;
    }
  }

  dispose() {}
}
