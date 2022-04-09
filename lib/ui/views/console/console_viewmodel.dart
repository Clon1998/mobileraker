import 'package:flutter/cupertino.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/domain/hive/machine.dart';
import 'package:mobileraker/dto/console/command.dart';
import 'package:mobileraker/dto/console/console_entry.dart';
import 'package:mobileraker/dto/server/klipper.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/components/dialog/action_dialogs.dart';
import 'package:mobileraker/ui/views/setting/setting_viewmodel.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _SelectedPrinterStreamKey = 'selectedPrinter';
const String _GCodeNotifyResp = 'notifyGcodeResp';
const String _ConsoleHistory = 'consoleHistory';
const String _ServerStreamKey = 'server';
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

class ConsoleViewModel extends MultipleStreamViewModel {
  final _logger = getLogger('ConsoleViewModel');

  final _navigationService = locator<NavigationService>();
  final _dialogService = locator<DialogService>();
  final _machineService = locator<MachineService>();
  final _settingService = locator<SettingService>();

  Machine? _machine;

  KlippyService? get _klippyService => _machine?.klippyService;

  PrinterService? get _printerService => _machine?.printerService;

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
    RegExp regExp =
        RegExp(terms.where((element) => element.isNotEmpty).join("|"));

    return history
        .where((element) => element.toLowerCase().contains(regExp))
        .toList(growable: false);
  }

  bool get isServerAvailable => dataReady(_ServerStreamKey);

  KlipperInstance get server => dataMap![_ServerStreamKey];

  List<Command> get availableCommands => dataMap?[_MacrosStreamKey] ?? [];

  bool get canUseEms =>
      isServerAvailable && server.klippyState == KlipperState.ready;

  bool get canSendCommand =>
      isServerAvailable &&
      server.klippyState == KlipperState.ready &&
      server.klippyConnected;

  String get printerName => _machine?.name ?? '';

  List<String> history = [];

  @override
  Map<String, StreamData> get streamsMap => {
        _SelectedPrinterStreamKey:
            StreamData<Machine?>(_machineService.selectedMachine),
        if (_klippyService != null) ...{
          _ServerStreamKey:
              StreamData<KlipperInstance>(_klippyService!.klipperStream)
        },
        if (_printerService != null) ...{
          _ConsoleHistory: StreamData<List<ConsoleEntry>>(
              _printerService!.gcodeStore().asStream()),
          _GCodeNotifyResp: StreamData<String>(
              _printerService!.gCodeResponseStream,
              transformData: _transformGCodeResponse),
          _MacrosStreamKey:
              StreamData<List<Command>>(_printerService!.gcodeHelp().asStream())
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

  onCommandSubmit() {
    String? command = textEditingController.text;
    if (textEditingController.text.isEmpty) return;
    _consoleEntries.add(ConsoleEntry(command, ConsoleEntryType.COMMAND,
        DateTime.now().millisecondsSinceEpoch / 1000));
    textEditingController.text = '';
    _printerService?.gCode(command);
    history.remove(command);
    history.insert(0, command);
    if (history.length > commandCacheSize) history.length = commandCacheSize;
    notifyListeners();
  }

  @override
  onData(String key, data) {
    super.onData(key, data);
    switch (key) {
      case _SelectedPrinterStreamKey:
        Machine? nmachine = data;
        if (nmachine == _machine) break;
        _machine = nmachine;
        notifySourceChanged(clearOldData: true);
        break;
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
        if (dialogResponse?.confirmed ?? false) _klippyService?.emergencyStop();
      });
    else
      _klippyService?.emergencyStop();
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
