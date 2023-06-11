/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/console/command.dart';
import 'package:mobileraker/data/dto/console/console_entry.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'console_controller.g.dart';

const int commandCacheSize = 25;

const List<String> additionalCmds = [
  'ABORT',
  'ACCEPT',
  'ADJUSTED',
  'GET_POSITION',
  'SET_RETRACTION',
  'TESTZ',
];

@riverpod
Future<List<Command>> availableMacros(AvailableMacrosRef ref) {
  return ref.watch(printerServiceSelectedProvider).gcodeHelp();
}

@riverpod
RefreshController consoleRefreshController(ConsoleRefreshControllerRef ref) =>
    RefreshController();

@riverpod
class ConsoleListController extends _$ConsoleListController {
  final RegExp _tempPattern =
      RegExp(r'^(?:ok\s+)?(B|C|T\d*):', caseSensitive: false);

  @override
  FutureOr<List<ConsoleEntry>> build() async {
    var initialHistory = await _fetchHistory();

    var printerService = ref.watch(printerServiceSelectedProvider);
    var gCodeResponseStream = printerService.gCodeResponseStream;
    var sub = gCodeResponseStream.listen((event) {
      if (_tempPattern.hasMatch(event)) {
        return;
      }
      var consoleEntry = ConsoleEntry(event, ConsoleEntryType.RESPONSE,
          DateTime.now().millisecondsSinceEpoch / 1000);
      state = AsyncValue.data([...state.value!, consoleEntry]);
    });

    ref.onDispose(() => sub.cancel());

    var refreshController = ref.watch(consoleRefreshControllerProvider);
    if (refreshController.isRefresh) {
      refreshController.refreshCompleted();
    }

    return initialHistory;
  }

  Future<List<ConsoleEntry>> _fetchHistory() async {
    var raw = await ref.read(printerServiceSelectedProvider).gcodeStore();
    var list = raw
        .where((element) => !_tempPattern.hasMatch(element.message))
        .toList(growable: false);
    return list;
  }

  onCommandSubmit(String command) {
    if (command.isEmpty || state.isLoading) return;
    state = AsyncValue.data([
      ...state.value!,
      ConsoleEntry(command, ConsoleEntryType.COMMAND,
          DateTime.now().millisecondsSinceEpoch / 1000)
    ]);
    ref.read(printerServiceSelectedProvider).gCode(command);
    ref.read(commandHistoryProvider.notifier).add(command);
  }
}


@riverpod
class CommandHistory extends _$CommandHistory {
  @override
  List<String> build() {
    return [];
  }

  add(String cmd) {
    List<String> tmp = state.toList();
    tmp.remove(cmd);
    tmp.insert(0, cmd);
    state = tmp.sublist(0, min(tmp.length, commandCacheSize));
  }
}
