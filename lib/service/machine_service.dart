import 'dart:async';

import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:hive/hive.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/domain/gcode_macro.dart';
import 'package:mobileraker/domain/macro_group.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/repository/printer_setting_hive_repository.dart';
import 'package:mobileraker/service/database_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

class MachineService {
  final _logger = getLogger('MachineService');

  // NotificationService notificationService = locator<NotificationService>();
  final _printerSettingRepo = locator<PrinterSettingHiveRepository>();
  late final _boxUuid = Hive.box<String>('uuidbox');

  late final BehaviorSubject<PrinterSetting?> selectedMachine;
  StreamSubscription<FGBGType>? _fgbgStreamSub;

  Stream<BoxEvent> get printerSettingEventStream =>
      Hive.box<PrinterSetting>('printers').watch();

  MachineService() {
    selectedMachine = BehaviorSubject<PrinterSetting?>();
    String? selectedUUID = _boxUuid.get('selectedPrinter');
    if (selectedUUID != null)
      _printerSettingRepo.get(uuid: selectedUUID).then((value) {
        if (value != null) setMachineActive(value);
      });

    _fgbgStreamSub = FGBGEvents.stream.listen((event) {
      if (event == FGBGType.foreground)
        selectedMachine.valueOrNull?.websocket.ensureConnection();
    });
  }

  Future<void> updateMachine(PrinterSetting printerSetting) async {
    await printerSetting.save();
    if (!selectedMachine.isClosed && isSelectedMachine(printerSetting))
      selectedMachine.add(printerSetting);
    return;
  }

  Future<PrinterSetting> addMachine(PrinterSetting printerSetting) async {
    await _printerSettingRepo.insert(printerSetting);
    await setMachineActive(printerSetting);
    return printerSetting;
  }

  Future<void> removeMachine(PrinterSetting printerSetting) async {
    _printerSettingRepo.remove(printerSetting.uuid);
    if (_boxUuid.get('selectedPrinter') == printerSetting.uuid) {
      PrinterSetting? machine = await _printerSettingRepo.get(index: 0);
      await setMachineActive(machine);
    }
  }

  Future<List<PrinterSetting>> fetchAll() {
    return _printerSettingRepo.fetchAll();
  }

  setMachineActive(PrinterSetting? printerSetting) async {
    if (printerSetting == selectedMachine.valueOrNull) return;
    // This case will be called when no printer is left! -> Select no printer as active printer
    if (printerSetting == null) {
      await _boxUuid.delete('selectedPrinter');
      if (!selectedMachine.isClosed) selectedMachine.add(null);
      return;
    }

    await _boxUuid.put('selectedPrinter', printerSetting.key);
    if (!selectedMachine.isClosed) selectedMachine.add(printerSetting);
  }

  selectNextMachine() async {
    List<PrinterSetting> list = await fetchAll();

    if (list.length < 2) return;
    _logger.i('Selecting next machine');
    int indexSelected = list.indexWhere(
        (element) => element.uuid == selectedMachine.valueOrNull?.uuid);
    int next = (indexSelected + 1) % list.length;
    setMachineActive(list[next]);
  }

  selectPreviousMachine() async {
    List<PrinterSetting> list = await fetchAll();
    if (list.length < 2) return;
    _logger.i('Selecting previous machine');
    int indexSelected = list.indexWhere(
        (element) => element.uuid == selectedMachine.valueOrNull?.uuid);
    int prev = (indexSelected - 1 < 0) ? list.length - 1 : indexSelected - 1;
    setMachineActive(list[prev]);
  }

  bool machineAvailable() {
    return selectedMachine.valueOrNull != null;
  }

  bool isSelectedMachine(PrinterSetting toCheck) =>
      toCheck == selectedMachine.valueOrNull;

  /// The FCM-Identifier is used by the python companion to
  /// identify the printer that sends a notification in case
  /// a user configured multiple printers in the app.
  /// Because of that the FCMIdentifier should be set only once!
  Future<String> fetchOrCreateFcmIdentifier(
      PrinterSetting printerSetting) async {
    var idFromSetting = printerSetting.fcmIdentifier;
    if (idFromSetting != null)
      return idFromSetting;
    DatabaseService databaseService = printerSetting.databaseService;

    String? item =
        await databaseService.getDatabaseItem('mobileraker', 'printerId');
    if (item == null) {
      String nId = Uuid().v4();
      _logger.i("Creating fcm-PrinterId in moonraker-Database: $nId");
      item = await databaseService.addDatabaseItem(
          'mobileraker', 'printerId', nId);
    }
    _logger.i(
        "Fcm-PrinterId from moonraker-Database in PrinterSettings = $item");

    printerSetting.fcmIdentifier = item;
    await printerSetting.save();
    return item!;
  }

  Future<PrinterSetting?> machineFromFcmIdentifier(String fcmIdentifier) async {
    List<PrinterSetting> machines = await fetchAll();
    for (PrinterSetting element in machines)
      if (element.fcmIdentifier == fcmIdentifier) return element;
    return null;
  }

  Future<int> indexOfMachine(PrinterSetting setting) async {
    int i = -1;
    List<PrinterSetting> machines = await fetchAll();
    for (PrinterSetting element in machines) {
      i++;
      if (element == setting) return i;
    }
    return i;
  }

  updateSettingMacros(PrinterSetting printerSetting, List<String> macros) {
    _logger.i("Updating Default Macros!");
    List<String> filteredMacros =
        macros.where((element) => !element.startsWith('_')).toList();
    List<MacroGroup> macroGroups = printerSetting.macroGroups;
    for (MacroGroup grp in macroGroups) {
      for (GCodeMacro macro in grp.macros) {
        filteredMacros.remove(macro.name);
      }
    }

    MacroGroup defaultGroup = macroGroups
        .firstWhere((element) => element.name == 'Default', orElse: () {
      MacroGroup group = MacroGroup(name: 'Default');
      macroGroups.add(group);
      return group;
    });

    defaultGroup.macros.addAll(filteredMacros.map((e) => GCodeMacro(e)));
  }

  dispose() {
    selectedMachine.close();
    _fgbgStreamSub?.cancel();

    fetchAll().then((machines) {
      for (PrinterSetting machine in machines) {
        machine.disposeServices();
      }
    });
  }
}
