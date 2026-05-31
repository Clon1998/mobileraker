/*
 * Copyright (c) 2024-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:common/common.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/model/file_operation.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/util/logger.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'fleet_print_controller.freezed.dart';
part 'fleet_print_controller.g.dart';

@freezed
sealed class FleetPrintArgs with _$FleetPrintArgs {
  const factory FleetPrintArgs({
    required String sourceMachineUUID,
    required String sourceMachineName,
    required GCodeFile file,
  }) = _FleetPrintArgs;
}

sealed class FleetTargetState {
  const FleetTargetState();
}

class FleetTargetPending extends FleetTargetState {
  const FleetTargetPending();
}

class FleetTargetChecking extends FleetTargetState {
  const FleetTargetChecking();
}

class FleetTargetUploading extends FleetTargetState {
  const FleetTargetUploading(this.progress);
  final double progress;
}

class FleetTargetSuccess extends FleetTargetState {
  const FleetTargetSuccess();
}

class FleetTargetFailed extends FleetTargetState {
  const FleetTargetFailed(this.reason);
  final String reason;
}

@freezed
sealed class FleetPrintState with _$FleetPrintState {
  const factory FleetPrintState({
    @Default([]) List<Machine> availableTargets,
    @Default([]) List<Machine> selectedTargets,
    @Default(false) bool started,
    @Default(false) bool downloadRequired,
    @Default(0.0) double downloadProgress,
    @Default(false) bool downloadComplete,
    Object? downloadError,
    @Default({}) Map<String, FleetTargetState> targetStates,
    @Default(false) bool isComplete,
  }) = _FleetPrintState;
}

@riverpod
class FleetPrintController extends _$FleetPrintController {
  final CancelToken _cancelToken = CancelToken();


  @override
  FleetPrintState build(FleetPrintArgs args) {
    ref.onDispose(_cancelToken.cancel);
    _loadAvailableTargets();
    return const FleetPrintState();
  }

  Future<void> _loadAvailableTargets() async {
    final all = await ref.read(allMachinesProvider.future);
    // Source machine first so users can see and select it at the top.
    final source = all.firstWhere((m) => m.uuid == args.sourceMachineUUID);

    final others = all.where((m) => m.uuid != args.sourceMachineUUID)
    //     .where((m) {
    //   final printer = ref.read(printerProvider(m.uuid)).valueOrNull;
    //   final klipper = ref.read(klipperProvider(m.uuid)).valueOrNull;
    //   final canStartPrint = printer != null &&
    //       printer.print.state != PrintState.printing &&
    //       printer.print.state != PrintState.paused;
    //   return canStartPrint && klipper?.klippyCanReceiveCommands == true;
    // })
        .toList();

    state = state.copyWith(availableTargets: [source, ...others]);
  }



  void toggleMachine(Machine machine) {
    final current = state.selectedTargets;
    if (current.any((m) => m.uuid == machine.uuid)) {
      state = state.copyWith(selectedTargets: current.where((m) => m.uuid != machine.uuid).toList());
    } else {
      state = state.copyWith(selectedTargets: [...current, machine]);
    }
  }

  Future<void> startFleetPrint() async {
    if (state.selectedTargets.isEmpty || state.started) return;

    final allTargets = List<Machine>.from(state.selectedTargets);
    final sourceTarget = allTargets.where((m) => m.uuid == args.sourceMachineUUID).firstOrNull;
    final otherTargets = allTargets.where((m) => m.uuid != args.sourceMachineUUID).toList();

    state = state.copyWith(
      started: true,
      targetStates: {for (final m in allTargets) m.uuid: const FleetTargetPending()},
    );

    // Source machine already has the file — start print immediately, before download.
    if (sourceTarget != null) {
      try {
        await ref
            .read(jrpcClientProvider(args.sourceMachineUUID))
            .sendJRpcMethod('printer.print.start', params: {'filename': args.file.pathForPrint});
        state = state.copyWith(
          targetStates: Map.from(state.targetStates)..[args.sourceMachineUUID] = const FleetTargetSuccess(),
        );
      } catch (e, s) {
        talker.error('[FleetPrintController] Print start on ${sourceTarget.name} failed', e, s);
        state = state.copyWith(
          targetStates: Map.from(state.targetStates)..[args.sourceMachineUUID] = FleetTargetFailed(e.toString()),
        );
      }
    }

    if (otherTargets.isEmpty) {
      state = state.copyWith(isComplete: true);
      return;
    }

    // Check all remote targets in parallel: does each already have the file?
    final needsUpload = <Machine>[];
    final alreadyHasFile = <Machine>[];

    state = state.copyWith(
      targetStates: {
        ...state.targetStates,
        for (final m in otherTargets) m.uuid: const FleetTargetChecking(),
      },
    );

    await Future.wait(
      otherTargets.map((target) async {
        try {
          final existing = await ref.read(fileServiceProvider(target.uuid)).getGCodeMetadata(args.file.pathForPrint);
          if (existing.size == args.file.size) {
            alreadyHasFile.add(target);
          } else {
            needsUpload.add(target);
          }
        } catch (_) {
          needsUpload.add(target);
        }
      }),
    );

    // Machines with the file confirmed: show hourglass while waiting for download to finish.
    if (alreadyHasFile.isNotEmpty) {
      state = state.copyWith(
        targetStates: {
          ...state.targetStates,
          for (final m in alreadyHasFile) m.uuid: const FleetTargetPending(),
        },
      );
    }

    if (needsUpload.isEmpty) {
      // No download needed — start all prints immediately.
      await Future.wait(_startPrintFutures(alreadyHasFile));
      state = state.copyWith(isComplete: true);
      return;
    }

    // Download the file from source once.
    state = state.copyWith(downloadRequired: true);

    final fileService = ref.read(fileServiceProvider(args.sourceMachineUUID));
    File? localFile;

    try {
      await for (final event in fileService.downloadFile(
        filePath: args.file.absolutPath,
        expectedFileSize: args.file.size,
        cancelToken: _cancelToken,
      )) {
        switch (event) {
          case FileOperationProgress(:final progress):
            state = state.copyWith(downloadProgress: progress);
          case FileDownloadComplete(:final file):
            localFile = file;
          case FileOperationCanceled():
            _markOthersFailed(needsUpload, 'Download canceled');
            return;
          default:
            break;
        }
      }
    } catch (e, s) {
      talker.error('[FleetPrintController] Download failed', e, s);
      state = state.copyWith(downloadError: e);
      _markOthersFailed(needsUpload, e.toString());
      return;
    }

    if (localFile == null) {
      _markOthersFailed(needsUpload, 'Download failed');
      return;
    }

    state = state.copyWith(downloadProgress: 1.0, downloadComplete: true);

    // Start prints on machines that already had the file + upload+print on the rest — all in parallel.
    await Future.wait([
      ..._startPrintFutures(alreadyHasFile),
      ...needsUpload.map((target) async {
        try {
          final multipartFile = await MultipartFile.fromFile(
            localFile!.path,
            filename: args.file.pathForPrint,
          );

          state = state.copyWith(
            targetStates: Map.from(state.targetStates)..[target.uuid] = const FleetTargetUploading(0),
          );

          await for (final event
              in ref.read(fileServiceProvider(target.uuid)).uploadFile(args.file.absolutPath, multipartFile, _cancelToken)) {
            switch (event) {
              case FileOperationProgress(:final progress):
                state = state.copyWith(
                  targetStates: Map.from(state.targetStates)..[target.uuid] = FleetTargetUploading(progress),
                );
              case FileUploadComplete():
                await ref
                    .read(jrpcClientProvider(target.uuid))
                    .sendJRpcMethod('printer.print.start', params: {'filename': args.file.pathForPrint});
                state = state.copyWith(
                  targetStates: Map.from(state.targetStates)..[target.uuid] = const FleetTargetSuccess(),
                );
              case FileOperationCanceled():
                state = state.copyWith(
                  targetStates: Map.from(state.targetStates)..[target.uuid] = const FleetTargetFailed('Upload canceled'),
                );
              default:
                break;
            }
          }
        } catch (e, s) {
          talker.error('[FleetPrintController] Upload to ${target.name} failed', e, s);
          state = state.copyWith(
            targetStates: Map.from(state.targetStates)..[target.uuid] = FleetTargetFailed(e.toString()),
          );
        }
      }),
    ]);

    state = state.copyWith(isComplete: true);
  }

  Iterable<Future<void>> _startPrintFutures(List<Machine> targets) => targets.map((target) async {
        try {
          await ref
              .read(jrpcClientProvider(target.uuid))
              .sendJRpcMethod('printer.print.start', params: {'filename': args.file.pathForPrint});
          state = state.copyWith(
            targetStates: Map.from(state.targetStates)..[target.uuid] = const FleetTargetSuccess(),
          );
        } catch (e, s) {
          talker.error('[FleetPrintController] Print start on ${target.name} failed', e, s);
          state = state.copyWith(
            targetStates: Map.from(state.targetStates)..[target.uuid] = FleetTargetFailed(e.toString()),
          );
        }
      });

  // Only marks the given targets failed, preserving any already-resolved state
  // (e.g. the source machine's print may have already succeeded before the download failed).
  void _markOthersFailed(List<Machine> targets, String reason) {
    state = state.copyWith(
      targetStates: {
        ...state.targetStates,
        for (final m in targets) m.uuid: FleetTargetFailed(reason),
      },
      isComplete: true,
    );
  }
}
