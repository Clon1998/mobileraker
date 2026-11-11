/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/dto/history/history_params.dart';
import 'package:common/data/dto/history/history_totals.dart';
import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/extensions/uri_extension.dart';
import 'package:common/util/logger.dart';
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

/// The lifetime totals of the printer, refreshed whenever a job starts or ends.
@riverpod
Future<HistoryTotals> historyTotals(Ref ref, String machineUUID) async {
  final service = ref.watch(historyServiceProvider(machineUUID));

  ref.listen(jrpcMethodEventProvider(machineUUID, 'notify_history_changed'), (previous, next) {
    if (next.isLoading) return;
    if (next.hasError) return;

    ref.invalidateSelf();
  });

  return service.getTotals();
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
    //   switch (next.value) {
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
      // Moonraker rejects null filters ("Unable to convert argument [before]"), so they are left out.
      RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod(
        'server.history.list',
        params: params?.toJson().let((it) => it..removeWhere((_, value) => value == null)),
      );

      List<Map<String, dynamic>> jobs = rpcResponse.result['jobs'].cast<Map<String, dynamic>>();
      talker.info(
        '[HistoryService ${_jRpcClient.clientType}@${_jRpcClient.uri.obfuscate()}] Job list fetched, got ${jobs.length} jobs!',
      );
      return List.generate(jobs.length, (index) => HistoricalPrintJob.fromJson(jobs[index]), growable: false);
    } on JRpcError catch (e, s) {
      talker.error('Error fetching job list', e, s);
      rethrow;
    }
  }

  /// The lifetime totals of the printer.
  /// https://moonraker.readthedocs.io/en/latest/external_api/history/#get-job-totals
  Future<HistoryTotals> getTotals() async {
    final rpcResponse = await _jRpcClient.sendJRpcMethod('server.history.totals');
    return HistoryTotals.fromJson((rpcResponse.result['job_totals'] as Map).cast<String, dynamic>());
  }

  /// Removes a single job from the history. The G-Code file itself is not touched.
  /// https://moonraker.readthedocs.io/en/latest/external_api/history/#delete-a-job
  Future<void> deleteJob(String jobId) async {
    talker.info('[HistoryService ${_jRpcClient.clientType}@${_jRpcClient.uri.obfuscate()}] Deleting job $jobId');
    await _jRpcClient.sendJRpcMethod('server.history.delete_job', params: {'uid': jobId});
  }

  dispose() {}
}
