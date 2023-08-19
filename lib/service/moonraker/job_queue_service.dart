/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/logger.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/job_queue/job_queue_event.dart';
import 'package:mobileraker/data/dto/job_queue/job_queue_status.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'job_queue_service.g.dart';

@riverpod
JobQueueService jobQueueService(JobQueueServiceRef ref, String machineUUID) {
  return JobQueueService(ref, machineUUID);
}

@riverpod
Stream<JobQueueStatus> jobQueue(JobQueueRef ref, String machineUUID) {
  ref.keepAlive();
  return ref.watch(jobQueueServiceProvider(machineUUID)).queueStatusStream;
}

@riverpod
JobQueueService jobQueueServiceSelected(JobQueueServiceSelectedRef ref) {
  return ref.watch(jobQueueServiceProvider(ref.watch(selectedMachineProvider).valueOrNull!.uuid));
}

@riverpod
Stream<JobQueueStatus> jobQueueSelected(JobQueueSelectedRef ref) async* {
  try {
    var machine = await ref.watchWhereNotNull(selectedMachineProvider);

    yield* ref.watchAsSubject(jobQueueProvider(machine.uuid));
  } on StateError catch (_) {
    // Just catch it. It is expected that the future/where might not complete!
  }
}

/// The JobQueueService is responsible for all interactions with the job API of Moonraker.
/// For more information check out
/// 1. https://moonraker.readthedocs.io/en/latest/web_api/#job-queue-apis
class JobQueueService {
  JobQueueService(AutoDisposeRef ref, String machineUUID)
      : _jRpcClient = ref.watch(jrpcClientProvider(machineUUID)) {
    ref.onDispose(dispose);
    ref.listen(jrpcMethodEventProvider(machineUUID, 'notify_job_queue_changed'), onJobQueueChanged);
  }

  final StreamController<JobQueueStatus> _queueStatusStreamCtrler = StreamController();

  Stream<JobQueueStatus> get queueStatusStream => _queueStatusStreamCtrler.stream;

  final JsonRpcClient _jRpcClient;

  Future<JobQueueStatus> queueStatus() async {
    logger.i('Queue status request...');

    try {
      RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod('server.job_queue.status');

      return JobQueueStatus.fromJson(rpcResponse.result);
    } on JRpcError catch (e) {
      throw MobilerakerException('Unable to fetch job queue status', parentException: e);
    }
  }

  Future<JobQueueStatus> enqueueJobs(List<String> files, [bool reset = false]) async {
    logger.i('Trying to enqueue files $files...');
    try {
      RpcResponse rpcResponse =
          await _jRpcClient.sendJRpcMethod('server.job_queue.post_job', params: {
        'filenames': files,
        'reset': reset,
      });

      return JobQueueStatus.fromJson(rpcResponse.result);
    } on JRpcError catch (e) {
      throw MobilerakerException('Error while adding files "$files" to the queue',
          parentException: e);
    }
  }

  Future<JobQueueStatus> enqueueJob(String file, [bool reset = false]) async {
    logger.i('Trying to enqueue file $file...');
    return enqueueJobs([file], reset);
  }

  Future<JobQueueStatus> dequeueJobs(List<String> jobIds) async {
    logger.i('Trying to dequeue files $jobIds...');
    try {
      RpcResponse rpcResponse =
          await _jRpcClient.sendJRpcMethod('server.job_queue.delete_job', params: {
        'job_ids': jobIds,
      });

      return JobQueueStatus.fromJson(rpcResponse.result);
    } on JRpcError catch (e) {
      throw MobilerakerException('Error while removing jobs $jobIds from the queue',
          parentException: e);
    }
  }

  Future<JobQueueStatus> dequeueJob(String jobId) async {
    logger.i('Trying to enqueue file $jobId...');
    return dequeueJobs([jobId]);
  }

  Future<JobQueueStatus> pauseQueue() async {
    logger.i('Trying to pause queue...');
    try {
      RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod('server.job_queue.pause');

      return JobQueueStatus.fromJson(rpcResponse.result);
    } on JRpcError catch (e) {
      throw MobilerakerException('Error while pausing the queue', parentException: e);
    }
  }

  Future<JobQueueStatus> startQueue() async {
    logger.i('Trying to start queue...');
    try {
      RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod('server.job_queue.start');

      return JobQueueStatus.fromJson(rpcResponse.result);
    } on JRpcError catch (e) {
      throw MobilerakerException('Error while starting the queue', parentException: e);
    }
  }

  /*

{
    "jsonrpc": "2.0",
    "method": "notify_job_queue_changed",
    "params": [
        {
            "action": "state_changed",
            "updated_queue": null,
            "queue_state": "paused"
        }
    ]
}

   */
  onJobQueueChanged(
      AsyncValue<Map<String, dynamic>>? previous, AsyncValue<Map<String, dynamic>> next) {
    if (next.isLoading) return;
    if (next.hasError) {
      // TODO: ADD ERROR HANDLING
      return;
    }
    var rawMessage = next.value!;

    logger.i('JobQueue event: $rawMessage');
  }

  dispose() {
    _queueStatusStreamCtrler.close();
  }
}
