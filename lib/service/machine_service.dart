import 'dart:async';
import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/data_source/moonraker_database_client.dart';
import 'package:mobileraker/data/dto/fcm/companion_meta.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/hive/octoeverywhere.dart';
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
import 'package:mobileraker/exceptions.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/firebase/analytics.dart';
import 'package:mobileraker/service/moonraker/announcement_service.dart';
import 'package:mobileraker/service/moonraker/file_service.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/octoeverywhere/app_connection_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/util/extensions/analytics_extension.dart';
import 'package:mobileraker/util/ref_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'setting_service.dart';

part 'machine_service.g.dart';

@riverpod
MachineService machineService(MachineServiceRef ref) {
  ref.keepAlive();
  return MachineService(ref);
}

@riverpod
Future<Machine?> machine(MachineRef ref, String uuid) async {
  ref.keepAlive();
  ref.onDispose(() => logger.e('machineProvider disposed $uuid'));

  logger.e('machineProvider creation STARTED $uuid');
  var future = await ref.watch(machineRepositoryProvider).get(uuid: uuid);
  logger.e('machineProvider creation DONE $uuid');
  return future;
}

@riverpod
Future<List<Machine>> allMachines(AllMachinesRef ref) async {
  return ref.watch(machineServiceProvider).fetchAll();
}

@riverpod
Future<MachineSettings> selectedMachineSettings(
    SelectedMachineSettingsRef ref) async {
  var machine = await ref.watchWhereNotNull(selectedMachineProvider);

  await ref.watchWhere<KlipperInstance>(klipperSelectedProvider,
      (c) => c.klippyState == KlipperState.ready, false);

  // TODO Refactor the fetchSettings into a new/machine based provider to make updating this easier!
  var fetchSettings =
      await ref.watch(machineServiceProvider).fetchSettings(machine);
  ref.keepAlive();
  return fetchSettings;
}

/// Service handling the management of a machine
class MachineService {
  MachineService(this.ref)
      : _machineRepo = ref.watch(machineRepositoryProvider),
        _selectedMachineService = ref.watch(selectedMachineServiceProvider),
        _settingService = ref.watch(settingServiceProvider),
        _appConnectionService = ref.watch(appConnectionServiceProvider);

  final AutoDisposeRef ref;
  final MachineHiveRepository _machineRepo;
  final SelectedMachineService _selectedMachineService;
  final SettingService _settingService;
  final AppConnectionService _appConnectionService;

  // final MachineSettingsMoonrakerRepository _machineSettingsRepository;

  Stream<BoxEvent> get machineEventStream =>
      Hive.box<Machine>('printers').watch();

  Future<void> updateMachine(Machine machine) async {
    await machine.save();
    logger.i('Updated machine: ${machine.name}');
    ref.read(analyticsProvider).logEvent(name: 'updated_machine');
    await ref.refresh(machineProvider(machine.uuid).future);
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
    FirebaseAnalytics firebaseAnalytics = ref.read(analyticsProvider);
    firebaseAnalytics.logEvent(name: 'add_machine');
    _machineRepo
        .count()
        .then((value) => firebaseAnalytics.updateMachineCount(value));

    await ref.read(machineProvider(machine.uuid).future);
    return machine;
  }

  Future<void> removeMachine(Machine machine) async {
    logger.i('Removing machine ${machine.uuid}');
    await _machineRepo.remove(machine.uuid);
    var firebaseAnalytics = ref.read(analyticsProvider);
    firebaseAnalytics.logEvent(name: 'remove_machine');
    _machineRepo
        .count()
        .then((value) => firebaseAnalytics.updateMachineCount(value));

    if (_selectedMachineService.isSelectedMachine(machine)) {
      logger.i(
          'Removed Machine ${machine.uuid} is active machine... move to next one...');
      List<Machine> remainingPrinters = await _machineRepo.fetchAll();

      Machine? nextMachine =
          remainingPrinters.isNotEmpty ? remainingPrinters.first : null;

      await _selectedMachineService.selectMachine(nextMachine);
    }

    // await Future.delayed(Duration(seconds: 4));
// DANGER!! It is really important to invalidate in the correct order!
    ref.invalidate(allMachinesProvider);
    ref.invalidate(announcementProvider(machine.uuid));
    ref.invalidate(announcementServiceProvider(machine.uuid));
    ref.invalidate(fileNotificationsProvider(machine.uuid));
    ref.invalidate(fileServiceProvider(machine.uuid));
    ref.invalidate(printerProvider(machine.uuid));
    ref.invalidate(printerServiceProvider(machine.uuid));
    ref.invalidate(klipperProvider(machine.uuid));
    ref.invalidate(klipperServiceProvider(machine.uuid));
    ref.invalidate(jrpcClientStateProvider(machine.uuid));
    ref.invalidate(jrpcClientProvider(machine.uuid));
    ref.invalidate(machineProvider(machine.uuid));
  }

  Future<Machine?> fetch(String uuid) {
    return _machineRepo.get(uuid: uuid);
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
    // Use this as a workaround to keep the repo active until method is done!
    var providerSubscription =
        ref.keepAliveExternally(fcmSettingsRepositoryProvider(machine.uuid));
    try {
      FcmSettingsRepository fcmRepo =
          ref.read(fcmSettingsRepositoryProvider(machine.uuid));

      // Remove DeviceFcmSettings if the device does not has the machineUUID anymore!
      var allDeviceSettings = await fcmRepo.all();
      var allMachineUUIDs = (await fetchAll()).map((e) => e.uuid);
      //Filter all entries out that dont have the same FCMTOKEN
      allDeviceSettings
          .removeWhere((key, value) => value.fcmToken != deviceFcmToken);
      // Remove all entries where a machine exist for
      allDeviceSettings
          .removeWhere((key, value) => allMachineUUIDs.contains(key));

      // Clear all of the DeviceFcmSettings that are left
      for (String uuid in allDeviceSettings.keys) {
        logger.w(
            'Found an old DeviceFcmSettings entry with uuid $uuid that is not present anymore!');
        fcmRepo.delete(uuid);
      }

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
    } finally {
      providerSubscription.close();
      logger.w('Sucka for ${machine.name}');
    }
  }

  Future<void> updateMachineFcmNotificationConfig(
      {required Machine machine,
      ProgressNotificationMode? mode,
      Set<PrintState>? printStates}) async {
    var keepAliveExternally = ref.keepAliveExternally(
        notificationSettingsRepositoryProvider(machine.uuid));
    try {
      var notificationSettingsRepository =
          ref.read(notificationSettingsRepositoryProvider(machine.uuid));

      logger.i(
          'Updating FCM Config for machine ${machine.name} (${machine.uuid})');

      var connectionResult = await ref.readWhere(
          jrpcClientStateProvider(machine.uuid),
          (state) => ![ClientState.connecting, ClientState.disconnected]
              .contains(state));
      if (connectionResult != ClientState.connected) {
        logger.w(
            '[${machine.name}@${machine.wsUrl}]Unable to propagate new notification settings because JRPC was not connected!');
        return;
      }

      List<Future> updateReq = [];
      if (mode != null) {
        var future = notificationSettingsRepository.updateProgressSettings(
            machine.uuid, mode.value);
        updateReq.add(future);
      }
      if (printStates != null) {
        var future = notificationSettingsRepository.updateStateSettings(
            machine.uuid, printStates);
        updateReq.add(future);
      }
      if (updateReq.isNotEmpty) await Future.wait(updateReq);
      logger.i(
          '[${machine.name}@${machine.wsUrl}] Propagated new notifcation settings');
    } finally {
      keepAliveExternally.close();
    }
  }

  Future<CompanionMetaData?> fetchCompanionMetaData(Machine machine) async {
    var machineUUID = machine.uuid;

    var connectionResult = await ref.readWhere(
        jrpcClientStateProvider(machine.uuid),
        (state) => ![ClientState.connecting, ClientState.disconnected]
            .contains(state));
    if (connectionResult != ClientState.connected) {
      logger.w(
          '[${machine.name}@${machine.wsUrl}]Unable to propagate new notification settings because JRPC was not connected!');
      throw const MobilerakerException('Machine not connected');
    }

    var databaseClient = ref.read(moonrakerDatabaseClientProvider(machineUUID));
    Map<String, dynamic>? databaseItem =
        await databaseClient.getDatabaseItem('mobileraker', key: 'fcm.client');

    if (databaseItem == null) {
      return null;
    }

    return CompanionMetaData.fromJson(databaseItem);
  }

  Future<List<Machine>> fetchMachinesWithoutCompanion() async {
    List<Machine> allMachines = await fetchAll();
    List<Machine> noCompanion = [];
    for (var machine in allMachines) {
      try {
        var meta = await fetchCompanionMetaData(machine);
        if (meta == null) noCompanion.add(machine);
      } catch (e) {
        logger.w(
            'Error while trying to fetch CompanionMeta for machine ${machine.name} (${machine.uuid})',
            e);
      }
    }
    return noCompanion;
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
      logger.e('Could not update macros, machine $machineUUID not found!');
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

  Future<Machine> linkMachineWithOctoeverywhere(Machine machineToLink) async {
    MoonrakerDatabaseClient moonrakerDatabaseClient =
        ref.read(moonrakerDatabaseClientProvider(machineToLink.uuid));
    String? octoPrinterId;
    try {
      octoPrinterId = await moonrakerDatabaseClient
          .getDatabaseItem('octoeverywhere', key: 'public.printerId');
    } on WebSocketException catch (e, s) {
      logger.w(
          'Rpc Client was not connected, could not fetch octo.printerId. User can select by himself!');
    }

    var appPortalResult =
        await _appConnectionService.linkAppWithOcto(printerId: octoPrinterId);

    return machineToLink
      ..octoEverywhere = OctoEverywhere.fromDto(appPortalResult);
  }
}
