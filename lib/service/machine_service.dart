import 'dart:async';

import 'package:hive/hive.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/data/datasource/moonraker_database_client.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/moonraker_db/gcode_macro.dart';
import 'package:mobileraker/data/model/moonraker_db/machine_settings.dart';
import 'package:mobileraker/data/model/moonraker_db/macro_group.dart';
import 'package:mobileraker/data/model/moonraker_db/temperature_preset.dart';
import 'package:mobileraker/data/repository/machine_hive_repository.dart';
import 'package:mobileraker/data/repository/machine_settings_moonraker_repository.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:uuid/uuid.dart';

/// Service handling the management of a machine
class MachineService {
  final _logger = getLogger('MachineService');
  final _machineRepo = locator<MachineHiveRepository>();
  final _selectedMachineService = locator<SelectedMachineService>();
  final MachineSettingsMoonrakerRepository _machineSettingsRepository =
      locator<MachineSettingsMoonrakerRepository>();

  final MoonrakerDatabaseClient _moonrakerDatabaseClient =
      locator<MoonrakerDatabaseClient>();

  Stream<BoxEvent> get machineEventStream =>
      Hive.box<Machine>('printers').watch();

  Future<void> updateMachine(Machine machine) async {
    await machine.save();
    if (_selectedMachineService.isSelectedMachine(machine))
      await _selectedMachineService.selectMachine(machine, true);

    return;
  }

  Future<MachineSettings> fetchSettings(Machine machine) async {
    // await _tryMigrateSettings(machine);
    MachineSettings? machineSettings =
        await _machineSettingsRepository.get(machine.jRpcClient);
    if (machineSettings == null) {
      machineSettings = _tryMigrateSettings(machine);
      await _machineSettingsRepository.update(machineSettings);
    }

    return machineSettings;
  }

  MachineSettings _tryMigrateSettings(Machine machine) {
    if (machine.speedXY == null) {
      _logger.i('No MachineSettings found... Creating from fallback');

      return MachineSettings.fallback();
    } else {
      _logger.i('No MachineSettings found... Migrating from known once');

      List<TemperaturePreset> migratedTemps = machine.temperaturePresets
          .map((element) => TemperaturePreset(
              name: element.name,
              uuid: element.uuid,
              extruderTemp: element.extruderTemp,
              bedTemp: element.bedTemp))
          .toList();

      List<MacroGroup> migratedMacroGrps = machine.macroGroups
          .map((element) => MacroGroup(
              name: element.name,
              uuid: element.uuid,
              macros: element.macros
                  .map((element) =>
                      GCodeMacro(name: element.name, uuid: element.uuid))
                  .toList()))
          .toList();

      var machineSettings = MachineSettings(
        temperaturePresets: migratedTemps,
        inverts: machine.inverts,
        speedXY: machine.speedXY!,
        speedZ: machine.speedZ,
        extrudeFeedrate: machine.extrudeFeedrate,
        moveSteps: machine.moveSteps,
        babySteps: machine.babySteps,
        extrudeSteps: machine.extrudeSteps,
        macroGroups: migratedMacroGrps,
      );
      machine
        ..speedXY = null
        ..save();
      return machineSettings;
    }
  }

  Future<void> updateSettings(
          Machine machine, MachineSettings machineSettings) =>
      _machineSettingsRepository.update(machineSettings, machine.jRpcClient);

  Future<Machine> addMachine(Machine machine) async {
    await _machineRepo.insert(machine);
    await _selectedMachineService.selectMachine(machine);
    return machine;
  }

  Future<void> removeMachine(Machine machine) async {
    _logger.i('Removing machine ${machine.uuid}');
    await _machineRepo.remove(machine.uuid);
    if (_selectedMachineService.isSelectedMachine(machine)) {
      _logger.i('Machine ${machine.uuid} is active machine');
      List<Machine> remainingPrinters = await _machineRepo.fetchAll();

      Machine? nextMachine =
          remainingPrinters.length > 0 ? remainingPrinters.first : null;

      await _selectedMachineService.selectMachine(nextMachine);
    }
  }

  Future<List<Machine>> fetchAll() {
    return _machineRepo.fetchAll();
  }

  Future<int> count() {
    return _machineRepo.count();
  }

  /// The FCM-Identifier is used by the python companion to
  /// identify the printer that sends a notification in case
  /// a user configured multiple printers in the app.
  /// Because of that the FCMIdentifier should be set only once!
  Future<String> fetchOrCreateFcmIdentifier(Machine machine) async {
    String? item = await _moonrakerDatabaseClient.getDatabaseItem('mobileraker',
        key: 'printerId', client: machine.jRpcClient);
    if (item == null) {
      String nId = Uuid().v4();
      item = await _moonrakerDatabaseClient.addDatabaseItem(
          'mobileraker', 'printerId', nId);
      _logger.i('Registered fcm-PrinterId in MoonrakerDB: $nId');
    } else {
      _logger.i(
          'Got FCM-PrinterID from MoonrakerDB for "${machine.name}(${machine.wsUrl})" to set in Settings: $item');
    }

    if (item != machine.fcmIdentifier) {
      machine.fcmIdentifier = item;
      await machine.save();
      _logger.i('Updated FCM-PrinterID in settings $item');
    }
    return item!;
  }

  Future<void> registerFCMTokenOnMachineNEW(
      Machine machine, String fcmToken) async {
    Map<String, dynamic>? item = await _moonrakerDatabaseClient.getDatabaseItem(
        'mobileraker',
        key: 'fcm.$fcmToken',
        client: machine.jRpcClient);
    if (item == null) {
      item = {'printerName': machine.name};
      item = await _moonrakerDatabaseClient.addDatabaseItem(
          'mobileraker', 'fcm.$fcmToken', item);
      _logger.i('Registered FCM Token in MoonrakerDB: $item');
    } else if (item['printerName'] != machine.name) {
      item['printerName'] = machine.name;
      item = await _moonrakerDatabaseClient.addDatabaseItem(
          'mobileraker', 'fcm.$fcmToken', item);
      _logger.i('Updated Printer\'s name in MoonrakerDB: $item');
    }
    _logger.i('Got FCM data from MoonrakerDB: $item');
  }

  Future<void> registerFCMTokenOnMachine(
      Machine machine, String fcmToken) async {
    var item = await _moonrakerDatabaseClient.getDatabaseItem('mobileraker',
        key: 'fcmTokens', client: machine.jRpcClient);
    if (item == null) {
      _logger.i('Creating fcmTokens in moonraker-Database');
      await _moonrakerDatabaseClient
          .addDatabaseItem('mobileraker', 'fcmTokens', [fcmToken]);
    } else {
      List<String> fcmTokens = List.from(item);
      if (!fcmTokens.contains(fcmToken)) {
        _logger.i('Adding token to existing fcmTokens in moonraker-Database');
        await _moonrakerDatabaseClient.addDatabaseItem(
            'mobileraker', 'fcmTokens', fcmTokens..add(fcmToken));
      } else {
        _logger
            .i('FCM token was registed for ${machine.name}(${machine.wsUrl})');
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

  updateMacrosInSettings(Machine machine, List<String> macros) async {
    _logger
        .i('Updating Default Macros for "${machine.name}(${machine.wsUrl})"!');
    MachineSettings machineSettings = await fetchSettings(machine);
    List<String> filteredMacros =
        macros.where((element) => !element.startsWith('_')).toList();
    List<MacroGroup> modifiableMacroGrps = machineSettings.macroGroups.toList();
    for (MacroGroup grp in modifiableMacroGrps) {
      for (GCodeMacro macro in grp.macros) {
        filteredMacros.remove(macro.name);
      }
    }

    MacroGroup defaultGroup = modifiableMacroGrps
        .firstWhere((element) => element.name == 'Default', orElse: () {
      MacroGroup group = MacroGroup(name: 'Default');
      modifiableMacroGrps.add(group);
      return group;
    });
    List<GCodeMacro> modifiableDefaultGrpMacros = defaultGroup.macros.toList();
    modifiableDefaultGrpMacros
        .addAll(filteredMacros.map((e) => GCodeMacro(name: e)));

    defaultGroup.macros = modifiableDefaultGrpMacros;
    machineSettings.macroGroups = modifiableMacroGrps;
    await _machineSettingsRepository.update(machineSettings);
  }

  dispose() {
    fetchAll().then((machines) {
      for (Machine machine in machines) {
        machine.disposeServices();
      }
    });
  }
}
