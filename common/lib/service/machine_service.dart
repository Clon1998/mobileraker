/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/octoeverywhere/app_portal_result.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/hive/progress_notification_mode.dart';
import 'package:common/data/model/model_event.dart';
import 'package:common/data/model/moonraker_db/fcm/apns.dart';
import 'package:common/data/repository/fcm/apns_repository_impl.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/obico/obico_tunnel_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/ui/locale_spy.dart';
import 'package:common/util/extensions/analytics_extension.dart';
import 'package:common/util/extensions/logging_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/dto/fcm/companion_meta.dart';
import '../data/dto/machine/gcode_macro.dart';
import '../data/model/moonraker_db/fcm/device_fcm_settings.dart';
import '../data/model/moonraker_db/fcm/notification_settings.dart';
import '../data/model/moonraker_db/settings/gcode_macro.dart';
import '../data/model/moonraker_db/settings/machine_settings.dart';
import '../data/model/moonraker_db/settings/macro_group.dart';
import '../data/repository/fcm/device_fcm_settings_repository.dart';
import '../data/repository/fcm/device_fcm_settings_repository_impl.dart';
import '../data/repository/fcm/notification_settings_repository_impl.dart';
import '../data/repository/machine_hive_repository.dart';
import '../data/repository/machine_settings_moonraker_repository.dart';
import '../data/repository/machine_settings_repository.dart';
import '../network/jrpc_client_provider.dart';
import '../network/moonraker_database_client.dart';
import 'firebase/analytics.dart';
import 'firebase/remote_config.dart';
import 'misc_providers.dart';
import 'moonraker/klippy_service.dart';
import 'moonraker/printer_service.dart';
import 'octoeverywhere/app_connection_service.dart';
import 'payment_service.dart';
import 'setting_service.dart';

part 'machine_service.g.dart';

@riverpod
MachineService machineService(MachineServiceRef ref) {
  ref.keepAlive();
  return MachineService(ref);
}

@riverpod
Future<Machine?> machine(MachineRef ref, String uuid) async {
  /// Using keepAliveFor ensures that the machineProvider remains active until all users of this provider are disposed.
  /// While ensuring that it eventually gets disposed.
  ref.keepAliveFor();
  ref.onDispose(() => logger.e('machineProvider disposed $uuid'));

  logger.i('machineProvider creation STARTED $uuid');
  var machine = await ref.watch(machineRepositoryProvider).get(uuid: uuid);
  logger.i('machineProvider creation DONE $uuid - returns null: ${machine == null}');
  return machine;
}

@riverpod
Future<List<Machine>> allMachines(AllMachinesRef ref) async {
  ref.listenSelf((previous, next) {
    next.whenData((value) => logger.i('Updated allMachinesProvider: ${value.map((e) => e.logName).join()}'));
  });

  logger.i('Received fetchAll');

  var settingService = ref.watch(settingServiceProvider);
  // Since the machineServiceProvider invalidates this provider, we need to use read. This is fine since machineServiceProvider is a service and non reactive!
  var machines = await ref.read(machineServiceProvider).fetchAll();
  final ordering = ref.watch(stringListSettingProvider(UtilityKeys.machineOrdering, []));

  logger.i('Received ordering $ordering');
  machines = machines.sorted((a, b) {
    final aOrder = ordering.indexOf(a.uuid).let((it) => it == -1 ? double.infinity : it);
    final bOrder = ordering.indexOf(b.uuid).let((it) => it == -1 ? double.infinity : it);
    return aOrder.compareTo(bOrder);
  });

  var isSupporter = await ref.watch(isSupporterAsyncProvider.future);
  logger.i('Received isSupporter $isSupporter');
  var maxNonSupporterMachines = ref.watch(remoteConfigIntProvider('non_suporters_max_printers'));
  logger.i('Max allowed machines for non Supporters is $maxNonSupporterMachines');
  if (isSupporter) {
    await settingService.delete(UtilityKeys.nonSupporterMachineCleanup);
  }

  if (isSupporter || maxNonSupporterMachines <= 0 || machines.length <= maxNonSupporterMachines) {
    return machines;
  }

  DateTime? cleanupDate = settingService.read<DateTime?>(UtilityKeys.nonSupporterMachineCleanup, null);

  if (cleanupDate == null) {
    cleanupDate = DateTime.now().add(const Duration(days: 7));
    cleanupDate = DateTime(cleanupDate.year, cleanupDate.month, cleanupDate.day);
    logger.i('Writing nonSupporter machine cleanup date $cleanupDate');
    settingService.write(UtilityKeys.nonSupporterMachineCleanup, cleanupDate);
    return machines;
  }

  if (cleanupDate.isBefore(DateTime.now())) {
    // if (cleanupDate.difference(DateTime.now()).inDays >= 0) {
    var oLen = machines.length;
    machines = machines.sublist(0, maxNonSupporterMachines);
    logger.i(
        'Hiding machines from user since he is not a supporter! Original len was $oLen, new length is ${machines.length}');
    return machines;
  }

  return machines;
}

@riverpod
Future<List<Machine>> hiddenMachines(HiddenMachinesRef ref) async {
  ref.listenSelf((previous, next) {
    next.whenData((value) => logger.i('Updated hiddenMachinesProvider: ${value.map((e) => e.logName).join()}'));
  });

  var machinesAvailableToUser = await ref.watch(allMachinesProvider.selectAsync((data) => data.map((e) => e.uuid)));
  // Since the machineServiceProvider invalidates this provider, we need to use read. This is fine since machineServiceProvider is a service and non reactive!
  var actualStoredMachines = await ref.read(machineServiceProvider).fetchAll();
  var hiddenMachines = actualStoredMachines.where((e) => !machinesAvailableToUser.contains(e.uuid));

  return hiddenMachines.toList(growable: false);
}

@riverpod
Stream<MachineSettings> machineSettings(MachineSettingsRef ref, String machineUUID) async* {
  ref.keepAliveFor();

  // Just ensure we have a machine to prevent errors while we dispose the machine/on remove the machine.
  final machine = await ref.watch(machineProvider(machineUUID).future);
  if (machine == null) return;

  // We listen to macro count changes to trigger a provider rebuild, allowing us to migrate the setting's macros
  var macroCnt = await ref.watch(printerProvider(machineUUID).selectAsync((data) => data.gcodeMacros.length));

  // Converts Klippy ready state to a stream of settings -> Emits new settings each time the Klippy state is transitioning to ready
  yield* ref
      .watchAsSubject(klipperProvider(machineUUID))
      .where((event) => event.klippyState == KlipperState.ready)
      .distinct()
      .asyncMap((event) async {
    var printerData = await ref.read(printerProvider(machineUUID).future);

    // We need to use read to prevent circular dependencies
    return await ref
        .read(machineServiceProvider)
        .fetchSettingsAndAdjustDefaultMacros(machineUUID, printerData.gcodeMacros);
  });
}

@riverpod
Stream<MachineSettings> selectedMachineSettings(SelectedMachineSettingsRef ref) async* {
  try {
    var machine = await ref.watch(selectedMachineProvider.future);
    if (machine == null) return;

    yield* ref.watchAsSubject(machineSettingsProvider(machine.uuid));
  } on StateError catch (_) {
    // Just catch it. It is expected that the future/where might not complete!
  }
}

/// Service handling the management of a machine
class MachineService {
  MachineService(this.ref)
      : _machineRepo = ref.watch(machineRepositoryProvider),
        _selectedMachineService = ref.watch(selectedMachineServiceProvider),
        _settingService = ref.watch(settingServiceProvider),
        _appConnectionService = ref.watch(appConnectionServiceProvider) {
    // ref.listen(provider, listener)

    ref.onDispose(dispose);
  }

  final AutoDisposeRef ref;
  final MachineHiveRepository _machineRepo;
  final SelectedMachineService _selectedMachineService;
  final SettingService _settingService;
  final AppConnectionService _appConnectionService;

  // final MachineSettingsMoonrakerRepository _machineSettingsRepository;

  final StreamController<ModelEvent<Machine>> _machineEventStreamCtler = StreamController.broadcast();

  Stream<ModelEvent<Machine>> get machineModelEvents => _machineEventStreamCtler.stream;

  Future<void> updateMachine(Machine machine) async {
    await _machineRepo.update(machine);
    logger.i('Updated machine: ${machine.logName}');
    ref.read(analyticsProvider).logEvent(name: 'updated_machine');
    _machineEventStreamCtler.add(ModelEvent.update(machine, machine.uuid));
    await ref.refresh(machineProvider(machine.uuid).future);
    var selectedMachineService = ref.read(selectedMachineServiceProvider);
    if (selectedMachineService.isSelectedMachine(machine)) {
      selectedMachineService.selectMachine(machine, true);
    }

    return;
  }

  Future<MachineSettings> fetchSettings({Machine? machine, String? machineUUID}) async {
    assert(machine != null || machineUUID != null, 'Either machine or machineUUID must be provided!');
    // await _tryMigrateSettings(machine);
    MachineSettings? machineSettings;
    try {
      machineSettings = await ref.read(machineSettingsRepositoryProvider(machineUUID ?? machine!.uuid)).get();
    } on JRpcError catch (e) {
      logger.e('Error while fetching settings for ${machine?.logName ?? machineUUID}', e);
      // check if error message is like 'Key 'settingss' in namespace 'mobileraker' not found'
      if (e.message !=
          'Key \'${MachineSettingsRepository.key}\' in namespace \'${MachineSettingsRepository.namespace}\' not found') {
        rethrow;
      }
    }

    if (machineSettings == null) {
      logger.i(
          'No settings found for ${machine?.logName ?? machineUUID}, falling back to default and writing it to database!');
      machineSettings = MachineSettings.fallback();
      ref.read(machineSettingsRepositoryProvider(machineUUID ?? machine!.uuid)).update(machineSettings);
    } else {
      logger.i('Fetched settings for ${machine?.logName ?? machineUUID}: $machineSettings');
    }

    return machineSettings;
  }

  Future<void> updateSettings(Machine machine, MachineSettings machineSettings) {
    return ref.read(machineSettingsRepositoryProvider(machine.uuid)).update(machineSettings);
  }

  Future<Machine> addMachine(Machine machine) async {
    logger.i('Trying to inser machine ${machine.logName}');
    await _machineRepo.insert(machine);
    logger.i('Inserted machine ${machine.logName}');
    await _selectedMachineService.selectMachine(machine);
    ref.invalidate(allMachinesProvider);
    FirebaseAnalytics firebaseAnalytics = ref.read(analyticsProvider);
    firebaseAnalytics.logEvent(name: 'add_machine');
    _machineRepo.count().then((value) => firebaseAnalytics.updateMachineCount(value));

    await ref.read(machineProvider(machine.uuid).future);
    _machineEventStreamCtler.add(ModelEvent.insert(machine, machine.uuid));

    return machine;
  }

  Future<void> removeMachine(Machine machine) async {
    logger.i('Removing machine ${machine.uuid}');
    try {
      await ref.read(deviceFcmSettingsRepositoryProvider(machine.uuid)).delete(machine.uuid);
    } catch (e) {
      logger.w('Was unable to delete FCM settings from machine that is about to get deleted...', e);
    }

    await _machineRepo.remove(machine.uuid);
    _machineEventStreamCtler.add(ModelEvent.delete(machine, machine.uuid));
    var firebaseAnalytics = ref.read(analyticsProvider);
    firebaseAnalytics.logEvent(name: 'remove_machine');
    _machineRepo.count().then((value) => firebaseAnalytics.updateMachineCount(value));

    if (_selectedMachineService.isSelectedMachine(machine)) {
      logger.i('Removed Machine ${machine.uuid} is active machine... move to next one...');
      List<Machine> remainingPrinters = await _machineRepo.fetchAll();

      Machine? nextMachine = remainingPrinters.isNotEmpty ? remainingPrinters.first : null;

      await _selectedMachineService.selectMachine(nextMachine);
    }

    /// Replace the manual invalidation. The machineProvider is now not kept alive, only up to 30 sec so
    /// It automatically invalidates itself after that if not used anymore.

    // await Future.delayed(Duration(seconds: 4));
// DANGER!! It is really important to invalidate in the correct order!
//     // Announcements API
//     ref.invalidate(announcementProvider(machine.uuid));
//     ref.invalidate(announcementServiceProvider(machine.uuid));
//     // Files API
//     ref.invalidate(fileNotificationsProvider(machine.uuid));
//     ref.invalidate(fileServiceProvider(machine.uuid));
//     // Webcam API
//     ref.invalidate(webcamServiceProvider(machine.uuid));
//
//     // Settings
//     // ref.invalidate(machineSettingsProvider(machine.uuid));
//     // Printer API
//     ref.invalidate(printerProvider(machine.uuid));
//     ref.invalidate(printerServiceProvider(machine.uuid));
//     // Klippy API
//     ref.invalidate(klipperProvider(machine.uuid));
//     ref.invalidate(klipperServiceProvider(machine.uuid));
//     // I/O
//     ref.invalidate(baseOptionsProvider);
//     ref.invalidate(httpClientProvider);
//     ref.invalidate(jrpcClientManagerProvider(machine.uuid));
//     ref.invalidate(dioClientProvider(machine.uuid));
//     ref.invalidate(jrpcClientStateProvider(machine.uuid));
//     ref.invalidate(jrpcClientProvider(machine.uuid));
//     // Actual machine
//     ref.invalidate(machineProvider(machine.uuid));
    // ref.invalidate(selectedMachineProvider);
    ref.invalidate(allMachinesProvider);
    logger.i('Removed machine ${machine.uuid}');
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

  Future<void> updateMachineFcmSettings(Machine machine, String deviceFcmToken) async {
    /*

    "key": "fcm",
    "value": {
        "<machineId>": {
            "fcmToken":"<FCM-TOKEN>",
            "machineName": "V2.1111",
            "language": "en",
            "version": "0.9.9-android", // or -ios
            "settings": {
              "progressConfig": 0.25,
              "stateConfig": ["error","printing","paused"]
            },
            "apns:{
              "liveActivity": "........"
            }
        }
    }

     */
    // Use this as a workaround to keep the repo active until method is done!
    var providerSubscription = ref.keepAliveExternally(deviceFcmSettingsRepositoryProvider(machine.uuid));
    try {
      logger.i('${machine.logTagExtended} Trying to update DeviceFcmSettings');
      DeviceFcmSettingsRepository fcmRepo = ref.read(deviceFcmSettingsRepositoryProvider(machine.uuid));

      // Remove DeviceFcmSettings if the device does not has the machineUUID anymore!
      var allDeviceSettings = await fcmRepo.all();
      var allMachineUUIDs = (await fetchAll()).map((e) => e.uuid);
      // Filter all entries out that dont have the same FCMTOKEN
      // AND Remove all entries where a machine exist for
      allDeviceSettings.removeWhere((key, value) => value.fcmToken != deviceFcmToken || allMachineUUIDs.contains(key));

      // Clear all of the DeviceFcmSettings that are left
      for (String uuid in allDeviceSettings.keys) {
        logger.w(
            '${machine.logTagExtended} Found an old DeviceFcmSettings entry with uuid $uuid that is not present anymore');
        fcmRepo.delete(uuid);
      }

      DeviceFcmSettings? fcmSettings = await fcmRepo.get(machine.uuid);

      int progressModeInt = _settingService.readInt(AppSettingKeys.progressNotificationMode, -1);
      var progressMode = (progressModeInt < 0)
          ? ProgressNotificationMode.TWENTY_FIVE
          : ProgressNotificationMode.values[progressModeInt];

      var states = _settingService
          .read(AppSettingKeys.statesTriggeringNotification, 'standby,printing,paused,complete,error')
          .split(',')
          .toSet();

      final etaSources = _settingService.readList<String>(AppSettingKeys.etaSources).toSet();

      String? version;
      try {
        var packageInfo = await ref.watch(versionInfoProvider.future);

        version = '${packageInfo.version}-${Platform.operatingSystem}';
      } catch (e) {
        logger.w('Was unable to fetch version info', e);
      }

      final language = ref.read(activeLocaleProvider).toString();

      if (fcmSettings == null) {
        fcmSettings = DeviceFcmSettings.fallback(deviceFcmToken, machine.name, version);
        fcmSettings.settings =
            NotificationSettings(progress: progressMode.value, states: states, etaSources: etaSources);
        logger.i(
            '${machine.logTagExtended} Did not find DeviceFcmSettings in MoonrakerDB, trying to add it: $fcmSettings');
        await fcmRepo.update(machine.uuid, fcmSettings);
        logger.i('${machine.logTagExtended} Successfully added DeviceFcmSettings');
      } else if (fcmSettings.machineName != machine.name ||
          fcmSettings.fcmToken != deviceFcmToken ||
          fcmSettings.settings.progress != progressMode.value ||
          !setEquals(fcmSettings.settings.states, states) ||
          !setEquals(fcmSettings.settings.etaSources, etaSources) ||
          fcmSettings.version != version ||
          fcmSettings.language != language) {
        fcmSettings.version = version;
        fcmSettings.language = language;
        fcmSettings.machineName = machine.name;
        fcmSettings.fcmToken = deviceFcmToken;
        fcmSettings.settings =
            fcmSettings.settings.copyWith(progress: progressMode.value, states: states, etaSources: etaSources);
        logger.i('${machine.logTagExtended} Trying to update DeviceFcmSettings');
        await fcmRepo.update(machine.uuid, fcmSettings);
        logger.i('${machine.logTagExtended} Successfully updated DeviceFcmSettings');
      } else {
        logger.i('${machine.logTagExtended} DeviceFcmSettings is in sync!');
      }
      logger.i('${machine.logTagExtended} Latest DeviceFcmSettings is: $fcmSettings');
    } finally {
      providerSubscription.close();
    }
  }

  Future<void> updateMachineFcmNotificationConfig({
    required Machine machine,
    ProgressNotificationMode? mode,
    Set<PrintState>? printStates,
    bool? progressbar,
    List<String>? etaSources,
  }) async {
    var keepAliveExternally = ref.keepAliveExternally(notificationSettingsRepositoryProvider(machine.uuid));
    try {
      var notificationSettingsRepository = keepAliveExternally.read();

      logger.i('Updating FCM Config for machine ${machine.logName}');

      var connectionResult = await ref.readWhere(jrpcClientStateProvider(machine.uuid),
          (state) => ![ClientState.connecting, ClientState.disconnected].contains(state));
      if (connectionResult != ClientState.connected) {
        logger.w(
            '${machine.logTagExtended} Unable to propagate new notification settings because JRPC was not connected!');
        return;
      }

      List<Future> updateReq = [];
      if (mode != null) {
        var future = notificationSettingsRepository.updateProgressSettings(machine.uuid, mode.value);
        updateReq.add(future);
      }
      if (printStates != null) {
        var future = notificationSettingsRepository.updateStateSettings(machine.uuid, printStates);
        updateReq.add(future);
      }
      if (progressbar != null) {
        var future = notificationSettingsRepository.updateAndroidProgressbarSettings(machine.uuid, progressbar);
        updateReq.add(future);
      }
      if (etaSources != null) {
        var future = notificationSettingsRepository.updateEtaSourcesSettings(machine.uuid, etaSources);
        updateReq.add(future);
      }

      if (updateReq.isNotEmpty) await Future.wait(updateReq);
      logger.i('${machine.logTagExtended} Propagated new notification settings');
    } finally {
      keepAliveExternally.close();
    }
  }

  Future<void> updateMachineFcmLiveActivity({
    required Machine machine,
    String? liveActivityPushToken,
  }) async {
    var keepAliveExternally = ref.keepAliveExternally(apnsRepositoryProvider(machine.uuid));
    try {
      var repo = ref.read(apnsRepositoryProvider(machine.uuid));

      logger.i('Updating live activity in FCM for machine ${machine.logName}');

      var connectionResult = await ref.readWhere(jrpcClientStateProvider(machine.uuid),
          (state) => ![ClientState.connecting, ClientState.disconnected].contains(state));
      if (connectionResult != ClientState.connected) {
        logger.w('${machine.logTagExtended} Unable to Propagated live activity in FCM because JRPC was not connected!');
        return;
      }
      if (liveActivityPushToken == null) {
        await repo.delete(machine.uuid);
      } else {
        await repo.write(machine.uuid, APNs(liveActivity: liveActivityPushToken));
      }
      logger.i('${machine.logTagExtended} Propagated new live activity in FCM');
    } finally {
      keepAliveExternally.close();
    }
  }

  Future<void> updateApplePushNotificationToken(
    String machineUUID,
    String? liveActivityPushToken,
  ) async {
    final keepAliveExternally = ref.keepAliveExternally(apnsRepositoryProvider(machineUUID));
    try {
      logger.i('Trying to update Apple Push Notification Token for machine $machineUUID');
      final repo = ref.read(apnsRepositoryProvider(machineUUID));

      final connectionResult = await ref.readWhere(jrpcClientStateProvider(machineUUID),
          (state) => state == ClientState.connected || state == ClientState.connecting);

      if (connectionResult != ClientState.connected) {
        logger.w(
            'Unable to update Apple Push Notification Token because JRPC was not connected for machine $machineUUID');
        return;
      }

      if (liveActivityPushToken == null) {
        await repo.delete(machineUUID);
      } else {
        await repo.write(machineUUID, APNs(liveActivity: liveActivityPushToken));
      }
      logger.i('Successfully updated Apple Push Notification Token for machine $machineUUID');
    } catch (e) {
      logger.w('Error while trying to update Apple Push Notification Token for machine $machineUUID. Rethrowing...', e);
      rethrow;
    } finally {
      keepAliveExternally.close();
    }
  }

  Future<void> removeFCMCapability(Machine machine) async {
    try {
      await ref.read(deviceFcmSettingsRepositoryProvider(machine.uuid)).delete(machine.uuid);
    } catch (e) {
      logger.w('Was unable to delete FCM settings from machine', e);
    }
  }

  /// Removes all stored fcm tokens+configs from the machines moonraker database
  Future<void> resetFcmTokens(Machine machine) async {
    try {
      await ref.read(deviceFcmSettingsRepositoryProvider(machine.uuid)).deleteAll();
    } catch (e) {
      logger.w('Was unable to reset/deletaAll FCM settings from machine', e);
    }
  }

  Future<CompanionMetaData?> fetchCompanionMetaData(Machine machine) async {
    var machineUUID = machine.uuid;

    var connectionResult = await ref.readWhere(jrpcClientStateProvider(machine.uuid),
        (state) => ![ClientState.connecting, ClientState.disconnected].contains(state));
    if (connectionResult != ClientState.connected) {
      logger
          .w('${machine.logTagExtended} Unable to propagate new notification settings because JRPC was not connected!');
      throw const MobilerakerException('Machine not connected');
    }

    var databaseClient = ref.read(moonrakerDatabaseClientProvider(machineUUID));
    Map<String, dynamic>? databaseItem = await databaseClient.getDatabaseItem('mobileraker', key: 'fcm.client');

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
        logger.w('Error while trying to fetch CompanionMeta for machine ${machine.logName}', e);
      }
    }
    return noCompanion;
  }

  /// Fetches the settings for a machine and adjusts the default macros.
  ///
  /// This method fetches the settings for a machine with the provided UUID.
  /// It then adjusts the default macros based on the provided list of macros.
  /// If a macro already exists in the default group, it is not added again.
  /// If a macro does not exist in the default group, it is added.
  /// If a macro exists in the default group but not in the provided list, it is removed.
  ///
  /// This method is useful for keeping the default macros up to date with the actual macros
  /// that are available on the machine.
  ///
  /// [machineUUID] is the UUID of the machine to fetch the settings for.
  /// [macros] is the list of macros to adjust the default macros with.
  ///
  /// Throws a [MobilerakerException] if the machine with the provided UUID does not exist.
  ///
  /// Returns the updated [MachineSettings] for the machine.
  Future<MachineSettings> fetchSettingsAndAdjustDefaultMacros(
      String machineUUID, Map<String, GcodeMacro> macros) async {
    // Get the machine with the provided UUID
    final machine = await _machineRepo.get(uuid: machineUUID);

    if (machine == null) {
      logger.e('Could not update macros, machine $machineUUID not found!');
      return throw const MobilerakerException('Machine not found');
    }

    // Log the machine information
    logger.i('Updating Default Macros for "${machine.logNameExtended})"!');

    // Fetch the machine settings
    final machineSettings = await fetchSettings(machineUUID: machineUUID);

    // Filter out macros that start with '_'
    final filteredRawMacros = macros.values.where((element) => element.isVisible).toList();

    // Create a copy of the modifiable macro groups
    List<MacroGroup> modifiableMacroGrps = machineSettings.macroGroups.toList();

    bool hasUnavailableMacro = false;
    bool hasMarkedForRemoval = false;
    final now = DateTime.now();
    // Iterate through the macro groups and remove macros that already exist
    for (int i = 0; i < modifiableMacroGrps.length; i++) {
      final grp = modifiableMacroGrps[i];
      final mMacros = [
        // Filter out group macros that reached the 7 day limit after they were marked for removal
        for (var macro in grp.macros.where((m) => (m.forRemoval?.difference(now).inHours.abs() ?? 0) < 12))
          macro.copyWith(
            forRemoval: (macro.forRemoval ?? now).unless(filteredRawMacros.any((e) => e.name == macro.name)).also((it) {
              hasMarkedForRemoval = hasMarkedForRemoval || it == now;
              if (it == now) {
                logger.i('Marking macro "${macro.name}" for removal in 12 hr(s)!');
              }
            }),
          )
      ];

      modifiableMacroGrps[i] = grp.copyWith(macros: mMacros);

      hasUnavailableMacro = hasUnavailableMacro || grp.macros.length != mMacros.length;
      filteredRawMacros.removeWhere((macro) => grp.macros.any((existingMacro) => existingMacro.name == macro.name));
    }

    bool hasLegacyDefaultGroup = false;
    // Find the default macro group or create it if it doesn't exist
    final defaultGroup = modifiableMacroGrps.firstWhere((element) => element.isDefaultGroup, orElse: () {
      final legacyDefaultGrp = modifiableMacroGrps.firstWhereOrNull((element) => element.name == 'Default');

      if (legacyDefaultGrp != null) {
        hasLegacyDefaultGroup = true;
        logger.i('Found legacy default group, migrating it to the new default group format!');
        modifiableMacroGrps.remove(legacyDefaultGrp);

        return MacroGroup.defaultGroup(
            name: tr('pages.printer_edit.macros.default_grp'), macros: legacyDefaultGrp.macros);
      }

      return MacroGroup.defaultGroup(name: tr('pages.printer_edit.macros.default_grp'));
    });

    // If there's no legacy group and no new macros to add, return early
    if (!hasLegacyDefaultGroup && !hasUnavailableMacro && filteredRawMacros.isEmpty && !hasMarkedForRemoval)
      return machineSettings;

    if (hasUnavailableMacro) {
      logger.i('Removing macros that reached the 7 day limit after they were marked for removal!');
    }

    if (hasMarkedForRemoval) {
      logger.i('Some macros were marked for removal, they will be removed in 7 days!');
    }

    if (filteredRawMacros.isNotEmpty) {
      // Log the number of new macros being added to the default group
      logger.i('Adding ${filteredRawMacros.length} new macros to the default group!');

      // Create an updated default group with the combined macros
      final updatedDefaultGrp = defaultGroup.copyWith(
        macros: List.unmodifiable([...defaultGroup.macros, ...filteredRawMacros.map((e) => GCodeMacro(name: e.name))]),
      );

      // Update or add the default group to the list of modifiable macro groups
      if (modifiableMacroGrps.contains(defaultGroup)) {
        modifiableMacroGrps[modifiableMacroGrps.indexOf(defaultGroup)] = updatedDefaultGrp;
      } else {
        modifiableMacroGrps.add(updatedDefaultGrp);
      }
    }

    // Update the machine settings and save
    machineSettings.macroGroups = modifiableMacroGrps;
    await ref.read(machineSettingsRepositoryProvider(machine.uuid)).update(machineSettings);
    return machineSettings;
  }

  /// Links the machine to the octoEverywhere service
  Future<AppPortalResult> linkOctoEverywhere(Machine machineToLink) async {
    MoonrakerDatabaseClient moonrakerDatabaseClient = ref.read(moonrakerDatabaseClientProvider(machineToLink.uuid));
    String? octoPrinterId;
    try {
      octoPrinterId = await moonrakerDatabaseClient.getDatabaseItem('octoeverywhere', key: 'public.printerId');
    } on WebSocketException {
      logger.w('Rpc Client was not connected, could not fetch octo.printerId. User can select by himself!');
    }

    return _appConnectionService.linkAppWithOcto(printerId: octoPrinterId);
  }

  Future<Uri> linkObico(Machine machineToLink, Uri? baseUrl) async {
    MoonrakerDatabaseClient moonrakerDatabaseClient = ref.read(moonrakerDatabaseClientProvider(machineToLink.uuid));
    String? obicoPrinterId;
    try {
      obicoPrinterId = await moonrakerDatabaseClient.getDatabaseItem('obico', key: 'printer_id');
    } on WebSocketException {
      logger.w('Rpc Client was not connected, could not fetch obico.printer_id. User can select by himself!');
    }

    return ref.watch(obicoTunnelServiceProvider(baseUrl)).linkApp(printerId: obicoPrinterId);
  }

  Future<void> reordered(String machineUUID, int oldIndex, int newIndex) async {
    final allMachines = await ref.read(allMachinesProvider.future);
    if (oldIndex >= allMachines.length || newIndex >= allMachines.length) {
      logger.w('Invalid index for reordering machines: $oldIndex -> $newIndex');
      return;
    }
    final machine = allMachines[oldIndex];

    logger.i('Reordering machine ${machine.logName} from $oldIndex to $newIndex');
    final readList = [..._settingService.readList(UtilityKeys.machineOrdering, <String>[])];

    // add all missing machines to the list
    for (var m in allMachines) {
      if (!readList.contains(m.uuid)) {
        readList.add(m.uuid);
      }
    }

    // remove the machine from the list
    readList.remove(machine.uuid);
    // insert the machine at the new index
    readList.insert(newIndex, machine.uuid);

    _settingService.write(UtilityKeys.machineOrdering, readList);
  }

  Future<void> dispose() async {
    await _machineEventStreamCtler.close();
  }
}
