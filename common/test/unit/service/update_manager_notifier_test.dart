/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/moonraker/update_manager_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:test_support/test_support.dart';

import '../../test_utils.dart';

/// Answers the status like [FakeJsonRpcClient], but an update, recover or rollback only once the test completes
/// [pending]: Moonraker answers those when they are done.
class _UpdateRpcClient extends FakeJsonRpcClient {
  _UpdateRpcClient({super.responses});

  Completer<void> pending = Completer();

  @override
  Future<RpcResponse> sendJRpcMethod(String method, {dynamic params, Duration? timeout}) async {
    final response = await super.sendJRpcMethod(method, params: params, timeout: timeout);
    if (const {'machine.update.upgrade', 'machine.update.recover', 'machine.update.rollback'}.contains(method)) {
      await pending.future;
    }
    return response;
  }
}

void main() {
  setUpAll(setupTestLogger);

  const uuid = 'test-machine';

  Map<String, dynamic> statusJson({bool busy = false, String klipperRemoteHash = 'bbb'}) => {
    'busy': busy,
    'github_rate_limit': 60,
    'github_requests_remaining': 54,
    'version_info': {
      'system': {'configured_type': 'system', 'package_count': 2, 'package_list': ['a', 'b']},
      'klipper': {
        'configured_type': 'git_repo',
        'version': 'v0.12.0',
        'remote_version': 'v0.13.0',
        'current_hash': 'aaa',
        'remote_hash': klipperRemoteHash,
      },
      'mainsail': {'configured_type': 'web', 'version': 'v2.1.0', 'remote_version': 'v2.2.0'},
    },
  };

  late _UpdateRpcClient rpc;
  late StreamController<Map<String, dynamic>> responses;
  late StreamController<Map<String, dynamic>> refreshed;
  late StreamController<Map<String, dynamic>> sudoAlerts;

  ProviderContainer makeContainer({Map<String, dynamic> Function()? status}) {
    rpc = _UpdateRpcClient(
      responses: {
        'machine.update.status': (_) => (status ?? statusJson)(),
        'machine.update.refresh': (_) => statusJson(klipperRemoteHash: 'ccc'),
      },
    );
    responses = StreamController.broadcast();
    refreshed = StreamController.broadcast();
    sudoAlerts = StreamController.broadcast();
    addTearDown(sudoAlerts.close);
    addTearDown(responses.close);
    addTearDown(refreshed.close);

    final container = ProviderContainer.test(
      overrides: [
        jrpcClientProvider(uuid).overrideWithValue(rpc),
        jrpcClientStateProvider(uuid).overrideWith((ref) async => ClientState.connected),
        jrpcMethodEventProvider(uuid, 'notify_update_response').overrideWith((ref) => responses.stream),
        jrpcMethodEventProvider(uuid, 'notify_update_refreshed').overrideWith((ref) => refreshed.stream),
        jrpcMethodEventProvider(uuid, 'notify_sudo_alert').overrideWith((ref) => sudoAlerts.stream),
      ],
    );
    // Like the page: both are listened to.
    addTearDown(container.listen(updateManagerStatusProvider(uuid), (_, _) {}).close);
    addTearDown(container.listen(updateProgressProvider(uuid), (_, _) {}).close);
    return container;
  }

  // A record does not deep-compare its params.
  void expectLastCall(String method, Object? params) {
    expect(rpc.calls.last.method, method);
    expect(rpc.calls.last.params, params);
  }

  void notify(String application, String message, {bool complete = false}) {
    responses.add({
      'params': [
        {'application': application, 'proc_id': 1, 'message': message, 'complete': complete},
      ],
    });
  }

  group('updateManagerStatusProvider', () {
    test('fetches the status once connected', () async {
      final container = makeContainer();

      final status = await container.read(updateManagerStatusProvider(uuid).future);

      expect(rpc.methods, ['machine.update.status']);
      expect(status.updaters.map((e) => e.name), ['system', 'klipper', 'mainsail']);
      expect(status.githubRequestsRemaining, 54);
    });

    test('notify_update_refreshed replaces the status', () async {
      final container = makeContainer();
      await container.read(updateManagerStatusProvider(uuid).future);

      refreshed.add({
        'params': [statusJson(busy: true)],
      });
      await pumpEventQueue();

      expect(container.read(updateManagerStatusProvider(uuid)).value?.busy, isTrue);
      expect(rpc.methods, ['machine.update.status'], reason: 'no second request');
    });

    test('refresh asks Moonraker to check and takes over its answer', () async {
      final container = makeContainer();
      await container.read(updateManagerStatusProvider(uuid).future);

      await container.read(updateManagerStatusProvider(uuid).notifier).refresh('klipper');

      expectLastCall('machine.update.refresh', {'name': 'klipper'});
      final klipper = container.read(updateManagerStatusProvider(uuid)).value!.updaters[1];
      expect(klipper.remoteHash, 'ccc');
    });
  });

  group('sudoRequestProvider', () {
    test('reads whether Moonraker waits for the password and follows its alerts', () async {
      final container = makeContainer();
      rpc.responses['machine.sudo.info'] = (_) => {
        'sudo_access': null,
        'linux_user': 'pi',
        'sudo_requested': false,
        'request_messages': [],
      };
      addTearDown(container.listen(sudoRequestProvider(uuid), (_, _) {}).close);

      final info = await container.read(sudoRequestProvider(uuid).future);
      expect(info.linuxUser, 'pi');
      expect(info.sudoRequested, isFalse);

      sudoAlerts.add({
        'params': [
          {
            'sudo_requested': true,
            'sudo_messages': ["Sudo password required to update Moonraker's systemd service."],
          },
        ],
      });
      await pumpEventQueue();

      var state = container.read(sudoRequestProvider(uuid)).value!;
      expect(state.sudoRequested, isTrue);
      expect(state.requestMessages, ["Sudo password required to update Moonraker's systemd service."]);
      expect(state.linuxUser, 'pi', reason: 'kept, the alert does not have it');

      // The result of the task that ran is not a request.
      sudoAlerts.add({
        'params': [
          {
            'sudo_requested': false,
            'sudo_messages': ['Service file updated.'],
          },
        ],
      });
      await pumpEventQueue();

      state = container.read(sudoRequestProvider(uuid)).value!;
      expect(state.sudoRequested, isFalse);
      expect(state.requestMessages, isEmpty);
    });

    test('submitPassword sends the password and returns the answers of the pending tasks', () async {
      final container = makeContainer();
      rpc.responses['machine.sudo.password'] = (_) => {
        'sudo_responses': ['Sudo password successfully set.'],
        'is_restarting': false,
      };
      addTearDown(container.listen(sudoRequestProvider(uuid), (_, _) {}).close);
      await container.read(sudoRequestProvider(uuid).future);

      final responses = await container.read(sudoRequestProvider(uuid).notifier).submitPassword('raspberry');

      expect(responses, ['Sudo password successfully set.']);
      expectLastCall('machine.sudo.password', {'password': 'raspberry'});
    });
  });

  group('updateProgressProvider', () {
    test('update all: plans the steps, collects the log and finishes on the final message', () async {
      final container = makeContainer();
      await container.read(updateManagerStatusProvider(uuid).future);

      unawaited(container.read(updateProgressProvider(uuid).notifier).upgrade());
      await pumpEventQueue();

      var state = container.read(updateProgressProvider(uuid));
      expect(state.phase, UpdatePhase.running);
      expect(state.action, UpdateAction.upgrade);
      expect(state.steps, ['system', 'mainsail', 'klipper'], reason: 'the order Moonraker updates in');
      expect(state.current, 'system');
      expectLastCall('machine.update.upgrade', null);

      notify('system', 'Updating packages…');
      notify('mainsail', 'Downloading mainsail.zip');
      await pumpEventQueue();

      state = container.read(updateProgressProvider(uuid));
      expect(state.current, 'mainsail');
      expect(state.currentStep, 1);
      expect(state.log.map((e) => e.message), ['Updating packages…', 'Downloading mainsail.zip']);

      notify('klipper', 'Update Finished…', complete: true);
      await pumpEventQueue();

      state = container.read(updateProgressProvider(uuid));
      expect(state.phase, UpdatePhase.finished);
      expect(state.log, hasLength(3));
      expect(state.logText, contains('[klipper] Update Finished…'));

      rpc.pending.complete();
      await pumpEventQueue();
      expect(container.read(updateProgressProvider(uuid)).phase, UpdatePhase.finished);
      expect(rpc.methods.where((m) => m == 'machine.update.status'), hasLength(2), reason: 'new versions fetched');
    });

    test('a single update only has its own step', () async {
      final container = makeContainer();
      await container.read(updateManagerStatusProvider(uuid).future);

      unawaited(container.read(updateProgressProvider(uuid).notifier).upgrade('klipper'));
      await pumpEventQueue();

      expect(container.read(updateProgressProvider(uuid)).steps, ['klipper']);
      expectLastCall('machine.update.upgrade', {'name': 'klipper'});

      // The answer of the request ends it too, e.g. if the final message got lost.
      rpc.pending.complete();
      await pumpEventQueue();
      expect(container.read(updateProgressProvider(uuid)).phase, UpdatePhase.finished);
    });

    test('a failing request fails the update and logs why', () async {
      final container = makeContainer();
      await container.read(updateManagerStatusProvider(uuid).future);

      unawaited(container.read(updateProgressProvider(uuid).notifier).recover('klipper', hard: true));
      await pumpEventQueue();
      expectLastCall('machine.update.recover', {'name': 'klipper', 'hard': true});

      rpc.pending.completeError(JRpcError(400, 'Update Refused: Klippy is printing'));
      await pumpEventQueue();

      final state = container.read(updateProgressProvider(uuid));
      expect(state.phase, UpdatePhase.failed);
      expect(state.action, UpdateAction.recover);
      expect(state.log.single.message, 'Update Refused: Klippy is printing');
    });

    test('rollback sends the name', () async {
      final container = makeContainer();
      await container.read(updateManagerStatusProvider(uuid).future);

      unawaited(container.read(updateProgressProvider(uuid).notifier).rollback('mainsail'));
      await pumpEventQueue();

      expectLastCall('machine.update.rollback', {'name': 'mainsail'});
      expect(container.read(updateProgressProvider(uuid)).action, UpdateAction.rollback);
    });

    test('does not start a second update while one runs', () async {
      final container = makeContainer();
      await container.read(updateManagerStatusProvider(uuid).future);
      final notifier = container.read(updateProgressProvider(uuid).notifier);

      unawaited(notifier.upgrade('klipper'));
      await pumpEventQueue();
      unawaited(notifier.upgrade('mainsail'));
      await pumpEventQueue();

      expect(rpc.methods.where((m) => m == 'machine.update.upgrade'), hasLength(1));
      expect(container.read(updateProgressProvider(uuid)).steps, ['klipper']);
    });

    test('follows an update that was started by another client', () async {
      final container = makeContainer();
      await container.read(updateManagerStatusProvider(uuid).future);

      notify('moonraker', 'Updating Moonraker…');
      await pumpEventQueue();

      var state = container.read(updateProgressProvider(uuid));
      expect(state.phase, UpdatePhase.running);
      expect(state.steps, ['moonraker']);
      expect(state.log.single.application, 'moonraker');

      notify('moonraker', 'Update Finished…', complete: true);
      await pumpEventQueue();
      expect(container.read(updateProgressProvider(uuid)).phase, UpdatePhase.finished);
    });

    test('a status that is not busy anymore ends an update whose final message got lost', () async {
      final container = makeContainer();
      await container.read(updateManagerStatusProvider(uuid).future);

      unawaited(container.read(updateProgressProvider(uuid).notifier).upgrade('klipper'));
      await pumpEventQueue();
      expect(container.read(updateProgressProvider(uuid)).isRunning, isTrue);

      refreshed.add({
        'params': [statusJson()],
      });
      await pumpEventQueue();

      expect(container.read(updateProgressProvider(uuid)).phase, UpdatePhase.finished);
    });
  });
}
