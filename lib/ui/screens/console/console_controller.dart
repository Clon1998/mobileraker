import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/console/command.dart';
import 'package:mobileraker/data/dto/console/console_entry.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

const int commandCacheSize = 25;

const List<String> additionalCmds = [
  'ABORT',
  'ACCEPT',
  'ADJUSTED',
  'GET_POSITION',
  'SET_RETRACTION',
  'TESTZ',
];

final consoleTextEditProvider = Provider.autoDispose((ref) {
  var textEditingController = TextEditingController();
  return textEditingController;
});

final consoleInputProvider =
    StateNotifierProvider.autoDispose<ConsoleInputController, String>((ref) =>
        ConsoleInputController(ref, ref.watch(consoleTextEditProvider)));

class ConsoleInputController extends StateNotifier<String> {
  ConsoleInputController(this.ref, this.textEditingController) : super('') {
    _init();
  }

  final AutoDisposeRef ref;
  final TextEditingController textEditingController;

  _init() {
    textEditingController.addListener(_onTextChanged);
    ref.onDispose(() => textEditingController.removeListener(_onTextChanged));
  }

  _onTextChanged() {
    var n = textEditingController.text;
    if (state != n) state = n;
  }
}

final availableMacrosProvider =
    FutureProvider.autoDispose<List<Command>>((ref) {
  return ref.watch(printerServiceSelectedProvider).gcodeHelp();
});

final suggestedMacroProvider = FutureProvider.autoDispose<List<String>>((ref) {
  List<String> potential = [];

  potential.addAll(ref.read(_commandHistoryProvider));
  // List<String> history = this.history.toList();

  var available = ref.watch(availableMacrosProvider).valueOrFullNull ?? [];

  Iterable<String> filteredAvailable = available.map((e) => e.cmd).where(
      (element) => !element.startsWith('_') && !potential.contains(element));
  potential.addAll(additionalCmds);
  potential.addAll(filteredAvailable);
  String text = ref.watch(consoleInputProvider).toLowerCase();
  if (text.isEmpty) return potential;

  List<String> terms = text.split(RegExp(r'\W+'));
  // RegExp regExp =
  //     RegExp(terms.where((element) => element.isNotEmpty).join("|"));

  var suggestions = potential
      .where((element) => terms.every((t) => element.toLowerCase().contains(t)))
      .toList(growable: false);

  logger.wtf('Got $text ${terms.length} with len ${suggestions.length}');
  return suggestions;
});

final consoleRefreshController =
    Provider.autoDispose((ref) => RefreshController());

final consoleListControllerProvider = StateNotifierProvider.autoDispose<
    ConsoleListController,
    AsyncValue<List<ConsoleEntry>>>((ref) => ConsoleListController(ref));

class ConsoleListController
    extends StateNotifier<AsyncValue<List<ConsoleEntry>>> {
  ConsoleListController(this.ref) : super(const AsyncValue.loading()) {
    _init();
  }

  final AutoDisposeRef ref;

  _init() async {
    var gCodeResponseStream =
        ref.watch(printerServiceSelectedProvider).gCodeResponseStream;
    await _fetchHistory();
    if (!mounted) return;
    var l = gCodeResponseStream.listen((event) {
      var consoleEntry = ConsoleEntry(event, ConsoleEntryType.RESPONSE,
          DateTime.now().millisecondsSinceEpoch / 1000);
      state = AsyncValue.data([...state.value!, consoleEntry]);
    });

    ref.onDispose(() {
      l.cancel();
    });
  }

  _fetchHistory() async {
    var raw = await ref.watch(printerServiceSelectedProvider).gcodeStore();
    var tempPattern = RegExp(r'^(?:ok\s+)?(B|C|T\d*):', caseSensitive: false);
    var list = raw
        .where((element) => !tempPattern.hasMatch(element.message))
        .toList(growable: false);
    if (!mounted) return;
    state = AsyncValue.data(list);
    var refreshController = ref.read(consoleRefreshController);

    if (refreshController.isRefresh) {
      refreshController.refreshCompleted();
    }
  }

  onKeyBoardInput(RawKeyEvent event) {
    if (event.isKeyPressed(LogicalKeyboardKey.enter)) onCommandSubmit();
  }

  onCommandSubmit() {
    String command = ref.read(consoleInputProvider);
    if (command.isEmpty || state.isLoading) return;
    state = AsyncValue.data([
      ...state.value!,
      ConsoleEntry(command, ConsoleEntryType.COMMAND,
          DateTime.now().millisecondsSinceEpoch / 1000)
    ]);
    ref.read(consoleTextEditProvider).clear();
    ref.read(printerServiceSelectedProvider).gCode(command);
    ref.read(_commandHistoryProvider.notifier).add(command);
  }
}

final _commandHistoryProvider =
    StateNotifierProvider<_CommandHistoryState, List<String>>(
        (ref) => _CommandHistoryState());

class _CommandHistoryState extends StateNotifier<List<String>> {
  _CommandHistoryState() : super([]);

  add(String cmd) {
    List<String> tmp = state.toList();
    tmp.remove(cmd);
    tmp.insert(0, cmd);
    state = tmp.sublist(0, min(tmp.length, commandCacheSize));
  }
}
