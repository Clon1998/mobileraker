import 'dart:async';

import 'package:hive/hive.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/domain/hive/gcode_macro.dart';
import 'package:mobileraker/domain/hive/machine.dart';
import 'package:mobileraker/domain/hive/macro_group.dart';
import 'package:mobileraker/repository/machine_hive_repository.dart';
import 'package:mobileraker/service/moonraker/database_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

/// Service handling the management of multiple machines/printers/klipper-enabled devices
class MachineService {
  MachineService() {
    selectedMachine = BehaviorSubject<Machine?>();
    String? selectedUUID = _boxUuid.get('selectedPrinter');
    if (selectedUUID != null)
      _machineRepo.get(uuid: selectedUUID).then((value) {
        if (value != null) setMachineActive(value);
      });
  }

  late final _boxUuid = Hive.box<String>('uuidbox');
  late final BehaviorSubject<Machine?> selectedMachine;

  final _logger = getLogger('MachineService');
  final _machineRepo = locator<MachineHiveRepository>();

  Stream<BoxEvent> get machineEventStream =>
      Hive.box<Machine>('printers').watch();

  Future<void> updateMachine(Machine machine) async {
    await machine.save();
    if (!selectedMachine.isClosed && isSelectedMachine(machine))
      selectedMachine.add(machine);

    return;
  }

  Future<Machine> addMachine(Machine machine) async {
    await _machineRepo.insert(machine);
    await setMachineActive(machine);
    return machine;
  }

  Future<void> removeMachine(Machine machine) async {
    _logger.i("Removing machine ${machine.uuid}");
    await _machineRepo.remove(machine.uuid);
    if (selectedMachine.valueOrNull == machine) {
      _logger.i("Machine ${machine.uuid} is active machine");
      List<Machine> remainingPrinters = await _machineRepo.fetchAll();

      Machine? nextMachine =
          remainingPrinters.length > 0 ? remainingPrinters.first : null;

      await setMachineActive(nextMachine);
    }
  }

  Future<List<Machine>> fetchAll() {
    return _machineRepo.fetchAll();
  }

  Future<int> count() {
    return _machineRepo.count();
  }

  setMachineActive(Machine? machine) async {
    if (machine == null) {
      // This case sets no printer as active!
      await _boxUuid.delete('selectedPrinter');
      if (!selectedMachine.isClosed) selectedMachine.add(null);

      _logger.i(
          "Selecting no printer as active Printer. Stream is closed?: ${selectedMachine.isClosed}");
      return;
    }

    if (machine == selectedMachine.valueOrNull) return;

    await _boxUuid.put('selectedPrinter', machine.key);
    if (!selectedMachine.isClosed) selectedMachine.add(machine);
  }

  selectNextMachine() async {
    List<Machine> list = await fetchAll();

    if (list.length < 2) return;
    _logger.i('Selecting next machine');
    int indexSelected = list.indexWhere(
        (element) => element.uuid == selectedMachine.valueOrNull?.uuid);
    int next = (indexSelected + 1) % list.length;
    setMachineActive(list[next]);
  }

  selectPreviousMachine() async {
    List<Machine> list = await fetchAll();
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

  bool isSelectedMachine(Machine toCheck) =>
      toCheck == selectedMachine.valueOrNull;

  /// The FCM-Identifier is used by the python companion to
  /// identify the printer that sends a notification in case
  /// a user configured multiple printers in the app.
  /// Because of that the FCMIdentifier should be set only once!
  Future<String> fetchOrCreateFcmIdentifier(Machine machine) async {
    DatabaseService databaseService = machine.databaseService;
    String? item =
        await databaseService.getDatabaseItem('mobileraker', 'printerId');
    if (item == null) {
      String nId = Uuid().v4();
      item = await databaseService.addDatabaseItem(
          'mobileraker', 'printerId', nId);
      _logger.i("Registered fcm-PrinterId in MoonrakerDB: $nId");
    } else {
      _logger.i("Got FCM-PrinterID from MoonrakerDB to set in Settings:$item");
    }

    if (item != machine.fcmIdentifier) {
      machine.fcmIdentifier = item;
      await machine.save();
      _logger.i("Updated FCM-PrinterID in settings $item");
    }
    return item!;
  }

  Future<void> registerFCMTokenOnMachineNEW(
      Machine machine, String fcmToken) async {
    DatabaseService databaseService = machine.databaseService;
    Map<String, dynamic>? item =
        await databaseService.getDatabaseItem('mobileraker', 'fcm.$fcmToken');
    if (item == null) {
      item = {'printerName': machine.name};
      item = await databaseService.addDatabaseItem(
          'mobileraker', 'fcm.$fcmToken', item);
      _logger.i("Registered FCM Token in MoonrakerDB: $item");
    } else if (item['printerName'] != machine.name) {
      item['printerName'] = machine.name;
      item = await databaseService.addDatabaseItem(
          'mobileraker', 'fcm.$fcmToken', item);
      _logger.i("Updated Printer's name in MoonrakerDB: $item");
    }
    _logger.i("Got FCM data from MoonrakerDB: $item");
  }

  Future<void> registerFCMTokenOnMachine(
      Machine machine, String fcmToken) async {
    DatabaseService databaseService = machine.databaseService;

    var item =
        await databaseService.getDatabaseItem('mobileraker', 'fcmTokens');
    if (item == null) {
      _logger.i("Creating fcmTokens in moonraker-Database");
      await databaseService
          .addDatabaseItem('mobileraker', 'fcmTokens', [fcmToken]);
    } else {
      List<String> fcmTokens = List.from(item);
      if (!fcmTokens.contains(fcmToken)) {
        _logger.i("Adding token to existing fcmTokens in moonraker-Database");
        await databaseService.addDatabaseItem(
            'mobileraker', 'fcmTokens', fcmTokens..add(fcmToken));
      }
    }
  }

  Future<Machine?> machineFromFcmIdentifier(String fcmIdentifier) async {
    List<Machine> machines = await fetchAll();
    for (Machine element in machines)
      if (element.fcmIdentifier == fcmIdentifier) return element;
    return null;
  }

  Future<int> indexOfMachine(Machine setting) async {
    int i = -1;
    List<Machine> machines = await fetchAll();
    for (Machine element in machines) {
      i++;
      if (element == setting) return i;
    }
    return i;
  }

  updateSettingMacros(Machine machine, List<String> macros) {
    _logger.i("Updating Default Macros!");
    List<String> filteredMacros =
        macros.where((element) => !element.startsWith('_')).toList();
    List<MacroGroup> macroGroups = machine.macroGroups;
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

    fetchAll().then((machines) {
      for (Machine machine in machines) {
        machine.disposeServices();
      }
    });
  }
}
