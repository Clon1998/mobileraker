import 'dart:math';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/console/command.dart';
import 'package:mobileraker/data/dto/console/console_entry.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
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

final availableMacrosProvider =
    FutureProvider.autoDispose<List<Command>>((ref) {
  return ref.watch(printerServiceSelectedProvider).gcodeHelp();
});

final consoleRefreshController =
    Provider.autoDispose((ref) => RefreshController());

final consoleListControllerProvider = StateNotifierProvider.autoDispose<
    ConsoleListController,
    AsyncValue<List<ConsoleEntry>>>((ref) => ConsoleListController(ref));

class ConsoleListController
    extends StateNotifier<AsyncValue<List<ConsoleEntry>>> {
  ConsoleListController(this.ref)
      : printerService = ref.watch(printerServiceSelectedProvider),
        super(const AsyncValue.loading()) {
    _init();
  }

  final AutoDisposeRef ref;
  final PrinterService printerService;

  _init() async {
    var gCodeResponseStream = printerService.gCodeResponseStream;
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
    var raw = await printerService.gcodeStore();
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

  onCommandSubmit(String command) {
    if (command.isEmpty || state.isLoading) return;
    state = AsyncValue.data([
      ...state.value!,
      ConsoleEntry(command, ConsoleEntryType.COMMAND,
          DateTime.now().millisecondsSinceEpoch / 1000)
    ]);
    printerService.gCode(command);
    ref.read(commandHistoryProvider.notifier).add(command);
  }
}

final commandHistoryProvider =
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
