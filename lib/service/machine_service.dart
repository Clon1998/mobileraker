import 'dart:async';

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
import 'package:mobileraker/service/firebase/analytics.dart';
import 'package:mobileraker/service/moonraker/announcement_service.dart';
import 'package:mobileraker/service/moonraker/file_service.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

final machineServiceProvider =
    Provider<MachineService>((ref) => MachineService(ref));

final allMachinesProvider = FutureProvider.autoDispose<List<Machine>>((ref) {
  return ref.watch(machineServiceProvider).fetchAll();
}, name: 'allMachinesProvider');

final selectedMachineSettingsProvider =
    FutureProvider.autoDispose<MachineSettings>((ref) async {
  //TODO: This leaks and is not that eefficient!
  var machine = await ref
      .watch(selectedMachineProvider.future)
      .asStream()
      .whereNotNull()
      .first;

  await ref.watch(jrpcClientStateSelectedProvider
      .selectAsync((data) => data == ClientState.connected));
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

  /// Ensure all services are setup/available/connected if they are also read just once!
  initializeAvailableMachines() async {
    List<Machine> all = await fetchAll();
    for (var machine in all) {
      ref.read(printerServiceProvider(machine.uuid));
      ref.read(klipperServiceProvider(machine.uuid));
    }
  }

  Future<void> updateMachine(Machine machine) async {
    await machine.save();
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
    ref.read(analyticsProvider).logEvent(name: 'add_machine');
    return machine;
  }

  Future<void> removeMachine(Machine machine) async {
    logger.i('Removing machine ${machine.uuid}');
    await _machineRepo.remove(machine.uuid);
    ref.invalidate(allMachinesProvider);
    ref.invalidate(jrpcClientProvider(machine.uuid));
    ref.invalidate(jrpcClientStateProvider(machine.uuid));
    ref.invalidate(printerProvider(machine.uuid));
    ref.invalidate(printerServiceProvider(machine.uuid));
    ref.invalidate(klipperProvider(machine.uuid));
    ref.invalidate(klipperServiceProvider(machine.uuid));
    ref.invalidate(fileNotificationsProvider(machine.uuid));
    ref.invalidate(fileServiceProvider(machine.uuid));
    ref.invalidate(announcementProvider(machine.uuid));
    ref.invalidate(announcementServiceProvider(machine.uuid));

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

  Future<void> updateMachineFcmConfig(
      Machine machine, String deviceFcmToken) async {
    /*

    "key": "fcm",
    "value": {
        "<device-fcm-token>": {
            "machineId":"Device local MACHIN UUIDE!",
            "machineName": "V2.1111",
            "language": "en",
            "progressConfig": 0.25,
            "stateConfig": ["error","printing","paused"]
        }
    }

     */

    MoonrakerDatabaseClient moonrakerDatabaseClient =
        ref.read(moonrakerDatabaseClientProvider(machine.uuid));
    String dbKey = 'fcm.$deviceFcmToken';
    Map<String, dynamic>? fcmCfg = await moonrakerDatabaseClient
        .getDatabaseItem('mobileraker', key: dbKey);
    if (fcmCfg == null) {
      fcmCfg = {
        'machineId': machine.uuid,
        'machineName': machine.name,
        'language': 'en',
        'progressConfig': 0.25,
        'stateConfig': ['error', 'printing', 'paused']
      };

      logger.i('Registered FCM Token in MoonrakerDB: $fcmCfg');

      fcmCfg = await moonrakerDatabaseClient.addDatabaseItem(
          'mobileraker', dbKey, fcmCfg);
    } else if (fcmCfg['machineName'] != machine.name) {
      fcmCfg['machineName'] = machine.name;
      fcmCfg = await moonrakerDatabaseClient.addDatabaseItem(
          'mobileraker', dbKey, fcmCfg);
    }

    logger.i('Current FCMConfig in MoonrakerDB: $fcmCfg');
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

  updateMacrosInSettings(String machineUUID, List<String> macros) async {
    Machine? machine = await _machineRepo.get(uuid: machineUUID);
    if (machine == null) {
      logger.e('Could not update macros, machine not found!');
      return;
    }
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

    if (filteredMacros.isEmpty) return;
    logger.i('Adding ${filteredMacros.length} new macros to default group!');
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
