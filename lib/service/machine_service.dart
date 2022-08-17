import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:hive/hive.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/data_source/moonraker_database_client.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/moonraker_db/gcode_macro.dart';
import 'package:mobileraker/data/model/moonraker_db/machine_settings.dart';
import 'package:mobileraker/data/model/moonraker_db/macro_group.dart';
import 'package:mobileraker/data/repository/machine_hive_repository.dart';
import 'package:mobileraker/data/repository/machine_settings_moonraker_repository.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

final machineServiceProvider = Provider((ref) => MachineService(ref));

final allMachinesProvider = FutureProvider.autoDispose<List<Machine>>(
    (ref) => ref.watch(machineServiceProvider).fetchAll());

final selectedMachineSettingsProvider =
    FutureProvider.autoDispose<MachineSettings>((ref) async {
  var machine = await ref
      .watch(selectedMachineProvider.future)
      .asStream()
      .whereNotNull()
      .first;

  await ref
      .watch(jrpcClientStateSelectedProvider.stream)
      .firstWhere((event) => event == ClientState.connected);
  var fetchSettings =
      await ref.watch(machineServiceProvider).fetchSettings(machine);
  ref.keepAlive();
  return fetchSettings;
});

/// Service handling the management of a machine
class MachineService {
  MachineService(this.ref)
      : _machineRepo = ref.watch(machineRepositoryProvider),
        _selectedMachineService = ref.watch(selectedMachineServiceProvider);
  final Ref ref;
  final MachineHiveRepository _machineRepo;
  final SelectedMachineService _selectedMachineService;

  // final MachineSettingsMoonrakerRepository _machineSettingsRepository;

  Stream<BoxEvent> get machineEventStream =>
      Hive.box<Machine>('printers').watch();

  Future<void> updateMachine(Machine machine) async {
    await machine.save();
    // ref.invalidate(jrpcClientProvider(machine.uuid));
    // ref.invalidate(jrpcClientStateProvider(machine.uuid));
    var selectedMachineService = ref.read(selectedMachineServiceProvider);
    if (selectedMachineService.isSelectedMachine(machine)) {
      selectedMachineService.selectMachine(machine, true);
    }

    return;
  }

  Future<MachineSettings> fetchSettings(Machine machine) async {
    // await _tryMigrateSettings(machine);
    MachineSettings machineSettings =
        await ref.read(machineSettingsRepositoryProvider(machine.uuid)).get() ??
            MachineSettings.fallback();
    ;

    return machineSettings;
  }

  Future<void> updateSettings(
      Machine machine, MachineSettings machineSettings) {
    return ref
        .read(machineSettingsRepositoryProvider(machine.uuid))
        .update(machineSettings);
  }

  Future<Machine> addMachine(Machine machine) async {
    await _machineRepo.insert(machine);
    await _selectedMachineService.selectMachine(machine);
    ref.invalidate(allMachinesProvider);
    return machine;
  }

  Future<void> removeMachine(Machine machine) async {
    logger.i('Removing machine ${machine.uuid}');
    await _machineRepo.remove(machine.uuid);
    ref.invalidate(allMachinesProvider);
    if (_selectedMachineService.isSelectedMachine(machine)) {
      logger.i('Machine ${machine.uuid} is active machine');
      List<Machine> remainingPrinters = await _machineRepo.fetchAll();

      Machine? nextMachine =
          remainingPrinters.isNotEmpty ? remainingPrinters.first : null;

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
    MoonrakerDatabaseClient moonrakerDatabaseClient =
        ref.read(moonrakerDatabaseClientProvider(machine.uuid));
    String? item = await moonrakerDatabaseClient.getDatabaseItem('mobileraker',
        key: 'printerId');
    if (item == null) {
      String nId = Uuid().v4();
      item = await moonrakerDatabaseClient.addDatabaseItem(
          'mobileraker', 'printerId', nId);
      logger.i('Registered fcm-PrinterId in MoonrakerDB: $nId');
    } else {
      logger.i(
          'Got FCM-PrinterID from MoonrakerDB for "${machine.name}(${machine.wsUrl})" to set in Settings: $item');
    }

    if (item != machine.fcmIdentifier) {
      machine.fcmIdentifier = item;
      await machine.save();
      logger.i('Updated FCM-PrinterID in settings $item');
    }
    return item!;
  }

  Future<void> registerFCMTokenOnMachineNEW(
      Machine machine, String fcmToken) async {
    MoonrakerDatabaseClient moonrakerDatabaseClient =
        ref.read(moonrakerDatabaseClientProvider(machine.uuid));
    Map<String, dynamic>? item = await moonrakerDatabaseClient
        .getDatabaseItem('mobileraker', key: 'fcm.$fcmToken');
    if (item == null) {
      item = {'printerName': machine.name};
      item = await moonrakerDatabaseClient.addDatabaseItem(
          'mobileraker', 'fcm.$fcmToken', item);
      logger.i('Registered FCM Token in MoonrakerDB: $item');
    } else if (item['printerName'] != machine.name) {
      item['printerName'] = machine.name;
      item = await moonrakerDatabaseClient.addDatabaseItem(
          'mobileraker', 'fcm.$fcmToken', item);
      logger.i('Updated Printer\'s name in MoonrakerDB: $item');
    }
    logger.i('Got FCM data from MoonrakerDB: $item');
  }

  Future<void> registerFCMTokenOnMachine(
      Machine machine, String fcmToken) async {
    MoonrakerDatabaseClient moonrakerDatabaseClient =
        ref.read(moonrakerDatabaseClientProvider(machine.uuid));
    var item = await moonrakerDatabaseClient.getDatabaseItem('mobileraker',
        key: 'fcmTokens');
    if (item == null) {
      logger.i('Creating fcmTokens in moonraker-Database');
      await moonrakerDatabaseClient
          .addDatabaseItem('mobileraker', 'fcmTokens', [fcmToken]);
    } else {
      List<String> fcmTokens = List.from(item);
      if (!fcmTokens.contains(fcmToken)) {
        logger.i('Adding token to existing fcmTokens in moonraker-Database');
        await moonrakerDatabaseClient.addDatabaseItem(
            'mobileraker', 'fcmTokens', fcmTokens..add(fcmToken));
      } else {
        logger
            .i('FCM token was registed for ${machine.name}(${machine.wsUrl})');
      }
    }
  }

  Future<Machine?> machineFromFcmIdentifier(String fcmIdentifier) async {
    List<Machine> machines = await fetchAll();
    for (Machine element in machines) {
      if (element.fcmIdentifier == fcmIdentifier) return element;
    }
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
    logger
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
    await ref
        .read(machineSettingsRepositoryProvider(machine.uuid))
        .update(machineSettings);
  }
}
