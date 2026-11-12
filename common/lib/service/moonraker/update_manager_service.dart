/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/dto/server/sudo_info.dart';
import 'package:common/data/dto/update_manager/update_status.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/extensions/updater_info_extension.dart';
import 'package:common/util/extensions/uri_extension.dart';
import 'package:common/util/logger.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/misc.dart' show KeepAliveLink;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_manager_service.freezed.dart';
part 'update_manager_service.g.dart';

@riverpod
UpdateManagerService updateManagerService(Ref ref, String machineUUID) {
  return UpdateManagerService(ref.watch(jrpcClientProvider(machineUUID)));
}

/// The state of the machine's update manager. Fetched once connected and replaced whenever Moonraker announces a
/// refresh (`notify_update_refreshed`), which it also does after an update.
@riverpod
class UpdateManagerStatus extends _$UpdateManagerStatus {
  @override
  Future<UpdateStatus> build(String machineUUID) async {
    final service = ref.watch(updateManagerServiceProvider(machineUUID));
    final connected = await ref.watch(
      jrpcClientStateProvider(machineUUID).selectAsync((s) => s == ClientState.connected),
    );
    // Stay in loading (keeping the previous value) until the client is connected again, e.g. after Moonraker
    // updated itself.
    if (!connected) return Completer<UpdateStatus>().future;

    ref.listen(jrpcMethodEventProvider(machineUUID, 'notify_update_refreshed'), (_, next) {
      if (!next.hasValue) return;
      try {
        final params = next.requireValue['params'] as List;
        state = AsyncData(UpdateStatus.fromJson((params.first as Map).cast<String, dynamic>()));
      } catch (e, s) {
        talker.warning('[UpdateManagerStatus($machineUUID)] Could not parse notify_update_refreshed', e, s);
      }
    });

    return service.fetchStatus();
  }

  /// Lets Moonraker check for updates, of [name] or of everything. Expensive on the host and counts against the
  /// GitHub rate limit, hence only to be called on the user's request. Moonraker refuses it while printing or
  /// updating.
  Future<void> refresh([String? name]) async {
    final status = await ref.read(updateManagerServiceProvider(machineUUID)).refresh(name);
    if (!ref.mounted) return;
    state = AsyncData(status);
  }
}

/// Whether Moonraker waits for the sudo password. Some updates need it, e.g. if Moonraker has to change its systemd
/// service; they stay pending until the password was set.
@riverpod
class SudoRequest extends _$SudoRequest {
  @override
  Future<SudoInfo> build(String machineUUID) async {
    final service = ref.watch(updateManagerServiceProvider(machineUUID));
    final connected = await ref.watch(
      jrpcClientStateProvider(machineUUID).selectAsync((s) => s == ClientState.connected),
    );
    if (!connected) return Completer<SudoInfo>().future;

    ref.listen(jrpcMethodEventProvider(machineUUID, 'notify_sudo_alert'), (_, next) {
      if (!next.hasValue) return;
      final params = next.requireValue['params'];
      if (params is! List || params.firstOrNull is! Map) return;
      final alert = params.first as Map;
      final requested = alert['sudo_requested'] == true;
      state = AsyncData(
        (state.value ?? const SudoInfo()).copyWith(
          sudoRequested: requested,
          // Without a pending request the messages are the results of the tasks that ran.
          requestMessages: requested ? [...?(alert['sudo_messages'] as List?)?.map((e) => e.toString())] : const [],
        ),
      );
    });

    return service.fetchSudoInfo();
  }

  /// Hands the password of the linux user to Moonraker, which then runs the pending tasks. Returns what they
  /// answered. Throws if the password is wrong or a task failed.
  Future<List<String>> submitPassword(String password) async {
    try {
      return await ref.read(updateManagerServiceProvider(machineUUID)).setSudoPassword(password);
    } finally {
      if (ref.mounted) ref.invalidateSelf();
    }
  }
}

enum UpdatePhase { idle, running, finished, failed }

enum UpdateAction { upgrade, recover, rollback }

/// A message Moonraker sent while it was updating [application].
@freezed
sealed class UpdateLogEntry with _$UpdateLogEntry {
  const factory UpdateLogEntry({required DateTime time, required String application, required String message}) =
      _UpdateLogEntry;
}

@freezed
sealed class UpdateProgressState with _$UpdateProgressState {
  const UpdateProgressState._();

  const factory UpdateProgressState({
    @Default(UpdatePhase.idle) UpdatePhase phase,
    @Default(UpdateAction.upgrade) UpdateAction action,

    /// The names of the software that is updated, in the order Moonraker goes through it.
    @Default([]) List<String> steps,

    /// The software Moonraker is working on.
    String? current,
    @Default([]) List<UpdateLogEntry> log,
  }) = _UpdateProgressState;

  bool get isRunning => phase == UpdatePhase.running;

  /// The position of [current] in [steps], the steps before it are done.
  int get currentStep => current == null ? 0 : steps.indexOf(current!).clamp(0, steps.length);

  /// The log as plain text, e.g. for the clipboard.
  String get logText => log.map((e) => '${e.time.toIso8601String()} [${e.application}] ${e.message}').join('\n');
}

/// The update, recover or rollback that currently runs on the machine with its live log
/// (`notify_update_response`), no matter whether it was started here or by another client.
///
/// Stays alive until the update is done, even if nobody listens anymore.
@riverpod
class UpdateProgress extends _$UpdateProgress {
  static const int _maxLogEntries = 500;

  KeepAliveLink? _link;

  @override
  UpdateProgressState build(String machineUUID) {
    ref.listen(jrpcMethodEventProvider(machineUUID, 'notify_update_response'), (_, next) {
      if (!next.hasValue) return;
      try {
        final params = next.requireValue['params'] as List;
        _onResponse((params.first as Map).cast<String, dynamic>());
      } catch (e, s) {
        talker.warning('[UpdateProgress($machineUUID)] Could not parse notify_update_response', e, s);
      }
    });

    // The final message can get lost, e.g. because the connection dropped while Moonraker updated itself. A status
    // that is not busy anymore tells the same: the one fetched after reconnecting, or the one Moonraker announces
    // (which does not change the provider if the update did not change a version).
    ref.listen(updateManagerStatusProvider(machineUUID), (_, next) {
      if (!state.isRunning || next.isLoading || !next.hasValue) return;
      if (!next.requireValue.busy) _end(UpdatePhase.finished);
    });
    ref.listen(jrpcMethodEventProvider(machineUUID, 'notify_update_refreshed'), (_, next) {
      if (!state.isRunning || !next.hasValue) return;
      final params = next.requireValue['params'];
      if (params is List && params.firstOrNull is Map && (params.first as Map)['busy'] != true) {
        _end(UpdatePhase.finished);
      }
    });

    return const UpdateProgressState();
  }

  /// Updates [name], or everything that has an update if no name is given.
  Future<void> upgrade([String? name]) {
    final plan = ref.read(updateManagerStatusProvider(machineUUID)).value?.updateAllPlan ?? const [];
    final steps = name == null ? [for (final it in plan) it.name] : [name];
    return _run(UpdateAction.upgrade, steps, (service) => service.upgrade(name));
  }

  /// Repairs the git repo of [name]: resets it, or with [hard] removes and clones it again.
  Future<void> recover(String name, {bool hard = false}) =>
      _run(UpdateAction.recover, [name], (service) => service.recover(name, hard: hard));

  /// Brings [name] back to the version prior to its last update.
  Future<void> rollback(String name) => _run(UpdateAction.rollback, [name], (service) => service.rollback(name));

  Future<void> _run(
    UpdateAction action,
    List<String> steps,
    Future<void> Function(UpdateManagerService service) call,
  ) async {
    if (state.isRunning) return;
    _link ??= ref.keepAlive();
    state = UpdateProgressState(phase: UpdatePhase.running, action: action, steps: steps, current: steps.firstOrNull);

    try {
      await call(ref.read(updateManagerServiceProvider(machineUUID)));
      if (!ref.mounted) return;
      _end(UpdatePhase.finished);
    } catch (e, s) {
      talker.warning('[UpdateProgress($machineUUID)] ${action.name} of $steps failed', e, s);
      if (!ref.mounted) return;
      // Whatever happened to the request, the update itself finished if Moonraker said so.
      if (!state.isRunning) return;
      _append(state.current ?? steps.firstOrNull ?? '', e is JRpcError ? e.message : e.toString());
      _end(UpdatePhase.failed);
    }
  }

  void _onResponse(Map<String, dynamic> json) {
    final application = json['application']?.toString() ?? '';
    final message = json['message']?.toString() ?? '';

    // Not started here: by another client, or before this provider was (re)created.
    if (!state.isRunning) {
      _link ??= ref.keepAlive();
      state = UpdateProgressState(phase: UpdatePhase.running, steps: [application], current: application);
    }
    if (!state.steps.contains(application)) state = state.copyWith(steps: [...state.steps, application]);
    state = state.copyWith(current: application);
    if (message.isNotEmpty) _append(application, message);

    if (json['complete'] == true) _end(UpdatePhase.finished);
  }

  void _append(String application, String message) {
    final entry = UpdateLogEntry(time: DateTime.now(), application: application, message: message);
    final log = [...state.log, entry];
    state = state.copyWith(log: log.length > _maxLogEntries ? log.sublist(log.length - _maxLogEntries) : log);
  }

  void _end(UpdatePhase phase) {
    if (!state.isRunning) return;
    state = state.copyWith(phase: phase);
    _link?.close();
    _link = null;
    // Moonraker announces the new versions on its own, this covers the case that the notification got lost.
    ref.invalidate(updateManagerStatusProvider(machineUUID));
  }
}

/// Commands of Moonraker's update manager. The state is owned by [updateManagerStatusProvider] and
/// [updateProgressProvider].
///
/// https://moonraker.readthedocs.io/en/latest/external_api/update_manager/
class UpdateManagerService {
  UpdateManagerService(this._jRpcClient);

  /// An update only answers once it is done, which can take a while (compiling python packages, apt, …).
  static const Duration _updateTimeout = Duration(minutes: 30);

  static const Duration _refreshTimeout = Duration(minutes: 3);

  final JsonRpcClient _jRpcClient;

  String get _logPrefix => '[UpdateManagerService ${_jRpcClient.clientType}@${_jRpcClient.uri.obfuscate()}]';

  Future<UpdateStatus> fetchStatus() async {
    talker.info('$_logPrefix Fetching update status');
    final response = await _jRpcClient.sendJRpcMethod('machine.update.status');
    return UpdateStatus.fromJson((response.result as Map).cast<String, dynamic>());
  }

  /// Checks for updates of [name], or of everything.
  Future<UpdateStatus> refresh([String? name]) async {
    talker.info('$_logPrefix Refreshing update status of ${name ?? 'everything'}');
    final response = await _jRpcClient.sendJRpcMethod(
      'machine.update.refresh',
      params: name == null ? null : {'name': name},
      timeout: _refreshTimeout,
    );
    return UpdateStatus.fromJson((response.result as Map).cast<String, dynamic>());
  }

  /// Updates [name], or everything. Completes once the update is done.
  Future<void> upgrade([String? name]) async {
    talker.info('$_logPrefix Upgrading ${name ?? 'everything'}');
    await _jRpcClient.sendJRpcMethod(
      'machine.update.upgrade',
      params: name == null ? null : {'name': name},
      timeout: _updateTimeout,
    );
  }

  /// Runs `git reset` on the repo of [name], with [hard] the repo is removed and cloned again.
  Future<void> recover(String name, {bool hard = false}) async {
    talker.info('$_logPrefix Recovering $name (hard: $hard)');
    await _jRpcClient.sendJRpcMethod(
      'machine.update.recover',
      params: {'name': name, 'hard': hard},
      timeout: _updateTimeout,
    );
  }

  Future<void> rollback(String name) async {
    talker.info('$_logPrefix Rolling back $name');
    await _jRpcClient.sendJRpcMethod('machine.update.rollback', params: {'name': name}, timeout: _updateTimeout);
  }

  /// Whether Moonraker waits for the sudo password.
  /// https://moonraker.readthedocs.io/en/latest/external_api/machine/#get-sudo-info
  Future<SudoInfo> fetchSudoInfo() async {
    final response = await _jRpcClient.sendJRpcMethod('machine.sudo.info');
    return SudoInfo.fromJson((response.result as Map).cast<String, dynamic>());
  }

  /// Sets the sudo password Moonraker uses until it restarts and runs the tasks that waited for it. Returns their
  /// answers. The password is neither stored nor logged by the app.
  /// https://moonraker.readthedocs.io/en/latest/external_api/machine/#set-sudo-password
  Future<List<String>> setSudoPassword(String password) async {
    talker.info('$_logPrefix Setting the sudo password');
    final response = await _jRpcClient.sendJRpcMethod(
      'machine.sudo.password',
      params: {'password': password},
      // The pending tasks run before Moonraker answers.
      timeout: _refreshTimeout,
    );
    final responses = (response.result as Map)['sudo_responses'];
    return [...?(responses as List?)?.map((e) => e.toString())];
  }
}
