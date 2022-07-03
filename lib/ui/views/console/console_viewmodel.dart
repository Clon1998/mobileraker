import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/data/dto/console/command.dart';
import 'package:mobileraker/data/dto/console/console_entry.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/common/mixins/klippy_mixin.dart';
import 'package:mobileraker/ui/common/mixins/selected_machine_mixin.dart';

import 'package:mobileraker/ui/components/dialog/action_dialogs.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _GCodeNotifyResp = 'notifyGcodeResp';
const String _ConsoleHistory = 'consoleHistory';
const String _MacrosStreamKey = 'availableMacros';
const int commandCacheSize = 25;

const List<String> additionalCmds = const [
  'ABORT',
  'ACCEPT',
  'ADJUSTED',
  'GET_POSITION',
  'SET_RETRACTION',
  'TESTZ',
];

class ConsoleViewModel extends MultipleStreamViewModel
    with SelectedMachineMixin, KlippyMixin {
  final _logger = getLogger('ConsoleViewModel');

  final _dialogService = locator<DialogService>();
  final _settingService = locator<SettingService>();

  RefreshController refreshController =
      RefreshController(initialRefresh: false);
  TextEditingController textEditingController = TextEditingController();

  bool get isConsoleHistoryAvailable => dataReady(_ConsoleHistory);

  List<ConsoleEntry> get _consoleEntries => dataMap![_ConsoleHistory];

  List<ConsoleEntry> get filteredConsoleEntries {
    var tempPattern = RegExp('^(?:ok\s+)?(B|C|T\d*):', caseSensitive: false);

    return _consoleEntries
        .where((element) => !tempPattern.hasMatch(element.message))
        .toList();
  }

  List<String> get filteredSuggestions {
    List<String> history = this.history.toList();
    Iterable<String> filteredAvailable = availableCommands
        .map((e) => e.cmd)
        .where((element) =>
            !element.startsWith('_') && !history.contains(element));
    history.addAll(additionalCmds);
    history.addAll(filteredAvailable);
    String text = textEditingController.text.toLowerCase();
    if (text.isEmpty) return history;

    List<String> terms = text.split(RegExp('\\W+'));
    // RegExp regExp =
    //     RegExp(terms.where((element) => element.isNotEmpty).join("|"));

    return history
        .where(
            (element) => terms.every((t) => element.toLowerCase().contains(t)))
        .toList(growable: false);
  }


  List<Command> get availableCommands => dataMap?[_MacrosStreamKey] ?? [];

  bool get canUseEms =>
      isKlippyInstanceReady && klippyInstance.klippyState == KlipperState.ready;

  bool get canSendCommand =>
      isConsoleHistoryAvailable &&
      isKlippyInstanceReady &&
      klippyInstance.klippyState == KlipperState.ready &&
          klippyInstance.klippyConnected;

  String get printerName => selectedMachine?.name ?? '';

  List<String> history = [];

  @override
  Map<String, StreamData> get streamsMap => {
        ...super.streamsMap,
        if (isSelectedMachineReady) ...{
          _ConsoleHistory: StreamData<List<ConsoleEntry>>(
              printerService.gcodeStore().asStream()),
          _GCodeNotifyResp: StreamData<String>(
              printerService.gCodeResponseStream,
              transformData: _transformGCodeResponse),
          _MacrosStreamKey:
              StreamData<List<Command>>(printerService.gcodeHelp().asStream())
        }
      };

  ConsoleEntry _transformGCodeResponse(String gCodeResp) {
    return ConsoleEntry(gCodeResp, ConsoleEntryType.RESPONSE,
        DateTime.now().millisecondsSinceEpoch / 1000);
  }

  onRefresh() async {
    notifySourceChanged(clearOldData: true);
    refreshController.refreshCompleted();
  }

  onConsoleCommandTap(ConsoleEntry consoleEntry) {
    if (consoleEntry.type != ConsoleEntryType.COMMAND) {
      _logger.w('Tried executing a non COMMAND command');
      return;
    }
    _setCurrentCommand(consoleEntry.message);
  }

  onSuggestionChipTap(String cmd) => _setCurrentCommand(cmd);

  _setCurrentCommand(String cmd) {
    textEditingController.text = cmd;
    textEditingController.selection = TextSelection.fromPosition(
      TextPosition(offset: textEditingController.text.length),
    );
  }

  onKeyBoardInput(event) {
    if (event.isKeyPressed(LogicalKeyboardKey.enter)) onCommandSubmit();
  }

  onCommandSubmit() {
    String? command = textEditingController.text;
    if (textEditingController.text.isEmpty) return;
    _consoleEntries.add(ConsoleEntry(command, ConsoleEntryType.COMMAND,
        DateTime.now().millisecondsSinceEpoch / 1000));
    textEditingController.text = '';
    printerService.gCode(command);
    history.remove(command);
    history.insert(0, command);
    if (history.length > commandCacheSize) history.length = commandCacheSize;
    notifyListeners();
  }

  @override
  onData(String key, data) {
    super.onData(key, data);
    switch (key) {
      case _GCodeNotifyResp:
        _consoleEntries.add(data);
        break;
      default:
        break;
    }
  }

  onEmergencyPressed() {
    if (_settingService.readBool(emsKey))
      emergencyStopConfirmDialog(_dialogService).then((dialogResponse) {
        if (dialogResponse?.confirmed ?? false) klippyService.emergencyStop();
      });
    else
      klippyService.emergencyStop();
  }

  @override
  initialise() {
    super.initialise();
    if (!initialised) {
      textEditingController.addListener(() => notifyListeners());
    }
  }

  @override
  dispose() {
    super.dispose();
    refreshController.dispose();
  }
}
