import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/hive/progress_notification_mode.dart';
import 'package:mobileraker/data/model/moonraker_db/device_fcm_settings.dart';
import 'package:mobileraker/data/model/moonraker_db/gcode_macro.dart';
import 'package:mobileraker/data/model/moonraker_db/machine_settings.dart';
import 'package:mobileraker/data/model/moonraker_db/macro_group.dart';
import 'package:mobileraker/data/model/moonraker_db/notification_settings.dart';
import 'package:mobileraker/data/repository/fcm_settings_repository.dart';
import 'package:mobileraker/data/repository/fcm_settings_repository_impl.dart';
import 'package:mobileraker/data/repository/machine_hive_repository.dart';
import 'package:mobileraker/data/repository/machine_settings_moonraker_repository.dart';
import 'package:mobileraker/data/repository/notification_settings_repository_impl.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/firebase/analytics.dart';
import 'package:mobileraker/service/moonraker/announcement_service.dart';
import 'package:mobileraker/service/moonraker/file_service.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:rxdart/rxdart.dart';

final machineServiceProvider = Provider.autoDispose<MachineService>((ref) {
  ref.keepAlive();
  return MachineService(ref);
}, name: 'machineServiceProvider');

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
        _selectedMachineService = ref.watch(selectedMachineServiceProvider),
        _settingService = ref.watch(settingServiceProvider);

  final AutoDisposeRef ref;
  final MachineHiveRepository _machineRepo;
  final SelectedMachineService _selectedMachineService;
  final SettingService _settingService;

  // final MachineSettingsMoonrakerRepository _machineSettingsRepository;

  Stream<BoxEvent> get machineEventStream =>
      Hive.box<Machine>('printers').watch();

  Future<void> updateMachine(Machine machine) async {
    await machine.save();
    logger.i('Updated machine: ${machine.name}');
    var selectedMachineService = ref.read(selectedMachineServiceProvider);
    if (selectedMachineService.isSelectedMachine(machine)) {
      selectedMachineService.selectMachine(machine, true);
    }
    ref.invalidate(jrpcClientProvider(machine.uuid));
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
        "<machineId>": {
            "fcmToken":"<FCM-TOKEN>",
            "machineName": "V2.1111",
            "language": "en",
            "settings": {
              "progressConfig": 0.25,
              "stateConfig": ["error","printing","paused"]
            }
        }
    }

     */

    FcmSettingsRepository fcmRepo =
        ref.watch(fcmSettingsRepositoryProvider(machine.uuid));

    DeviceFcmSettings? fcmCfg = await fcmRepo.get(machine.uuid);

    int progressModeInt =
        _settingService.readInt(selectedProgressNotifyMode, -1);
    var progressMode = (progressModeInt < 0)
        ? ProgressNotificationMode.TWENTY_FIVE
        : ProgressNotificationMode.values[progressModeInt];

    var states = _settingService
        .read(activeStateNotifyMode, 'standby,printing,paused,complete,error')
        .split(',')
        .toSet();

    if (fcmCfg == null) {
      fcmCfg = DeviceFcmSettings.fallback(deviceFcmToken, machine.name);
      fcmCfg.settings =
          NotificationSettings(progress: progressMode.value, states: states);
      logger.i('Registered FCM Token in MoonrakerDB: $fcmCfg');

      await fcmRepo.update(machine.uuid, fcmCfg);
    } else if (fcmCfg.machineName != machine.name ||
        fcmCfg.fcmToken != deviceFcmToken ||
        fcmCfg.settings.progress != progressMode.value ||
        !setEquals(fcmCfg.settings.states, states)) {
      fcmCfg.machineName = machine.name;
      fcmCfg.fcmToken = deviceFcmToken;
      fcmCfg.settings = fcmCfg.settings
          .copyWith(progress: progressMode.value, states: states);
      logger.i('Updating fcmCfgs');
      await fcmRepo.update(machine.uuid, fcmCfg);
    }

    logger.i('Current FCMConfig in MoonrakerDB: $fcmCfg');
  }

  Future<void> updateMachineFcmNotificationConfig(
      {required Machine machine,
      ProgressNotificationMode? mode,
      Set<PrintState>? printStates}) async {
    var notificationSettingsRepository =
        ref.read(notificationSettingsRepositoryProvider(machine.uuid));

    var rpcClient = ref.read(jrpcClientProvider(machine.uuid));
    var connected = await rpcClient.ensureConnection();
    if (!connected) {
      logger.w(
          '[${machine.name}@${machine.wsUrl}]Unable to propagate new notification settings because JRPC was not connected!');
      return;
    }

    if (mode != null) {
      notificationSettingsRepository.updateProgressSettings(
          machine.uuid, mode.value);
    }
    if (printStates != null) {
      notificationSettingsRepository.updateStateSettings(
          machine.uuid, printStates);
    }
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
