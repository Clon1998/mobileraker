/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:io';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/machine/printer.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/hive/notification.dart';
import 'package:common/data/model/model_event.dart';
import 'package:common/data/repository/notifications_hive_repository.dart';
import 'package:common/data/repository/notifications_repository.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/misc_providers.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/theme_service.dart';
import 'package:common/util/extensions/date_time_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/activity_update.dart';
import 'package:live_activities/models/live_activity_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'live_activity_service.g.dart';

@Riverpod(keepAlive: true)
LiveActivities liveActivity(LiveActivityRef ref) {
  return LiveActivities();
}

@riverpod
LiveActivityService liveActivityService(LiveActivityServiceRef ref) => LiveActivityService(ref);

class LiveActivityService {
  LiveActivityService(this.ref)
      : _machineService = ref.watch(machineServiceProvider),
        _settingsService = ref.watch(settingServiceProvider),
        _liveActivityAPI = ref.watch(liveActivityProvider),
        _notificationsRepository = ref.watch(notificationRepositoryProvider) {
    ref.keepAlive();
    ref.onDispose(dispose);
  }

  final AutoDisposeRef ref;
  final MachineService _machineService;
  final SettingService _settingsService;
  final LiveActivities _liveActivityAPI;
  final NotificationsRepository _notificationsRepository;
  final Map<String, ProviderSubscription<AsyncValue<Printer>>> _printerListeners = {};
  final Map<String, _ActivityEntry> _machineLiveActivityMap = {};
  final Map<String, Completer?> _updateLiveActivityLocks = {};
  final Map<String, Completer?> _handlePrinterDataLocks = {};
  StreamSubscription<ModelEvent<Machine>>? _machineUpdatesListener;
  StreamSubscription<ActivityUpdate>? _activityUpdateStreamSubscription;

  bool _disableClearing = false;

  Future<void> initialize() async {
    try {
      await _initIos();
      logger.i('Completed LiveActivityService init');
    } catch (e, s) {
      FirebaseCrashlytics.instance.recordError(
        e,
        s,
        reason: 'Error while setting up the LiveActivityService',
      );
      logger.w('Error encountered while trying to setup the LiveActivityService.', e, s);
    }
  }

  Future<void> _initIos() async {
    if (!Platform.isIOS) return;

    try {
      await _liveActivityAPI.init(appGroupId: 'group.mobileraker.liveactivity');

      _restoreActivityMap();
      _setupLiveActivityListener();
      _registerMachineHandlers();
      _registerAppLifecycleHandler();
    } catch (e, s) {
      if (e is PlatformException) {
        if (e.code == 'WRONG_IOS_VERSION') {
          logger.i('Could not initialize LiveActivityService because the iOS version is to low');
          return;
        }
      }
      logger.e('Error while setting up the LiveActivityService', e, s);
      rethrow;
    }
  }

  void _setupLiveActivityListener() {
    logger.i('Started to listen for LiveActivity updates');
    _activityUpdateStreamSubscription = _liveActivityAPI.activityUpdateStream.listen((event) async {
      logger.i('LiveActivity update: $event');

      var entry = _machineLiveActivityMap.entries.firstWhereOrNull((entry) => entry.value.id == event.activityId);
      if (entry == null) return;
      var machine = await ref.read(machineProvider(entry.key).future);
      if (machine == null) return;

      event.mapOrNull(
        active: (state) async {
          logger.i(
              'Updating Pushtoken for ${machine.name} LiveActivity ${state.activityId} to ${state.activityToken} fro');
          _machineLiveActivityMap[entry.key] = _ActivityEntry(state.activityId, state.activityToken);
          _machineService
              .updateMachineFcmLiveActivity(machine: machine, liveActivityPushToken: state.activityToken)
              .ignore();
        },
        // ended: (state) => _endLiveActivity(machine),
      );
    });
  }

  void _registerMachineHandlers() {
    ref.listen(
      allMachinesProvider,
      (_, next) => next.whenData((machines) {
        var listenersToClose = _printerListeners.keys.where((e) => machines.any((m) => m.uuid == e));
        var listenersToOpen = machines.whereNot((e) => _printerListeners.containsKey(e.uuid));

        var closed = 0;
        for (var uuid in listenersToClose) {
          closed++;
          _printerListeners[uuid]?.close();
          _printerListeners.remove(uuid);
        }

        var opened = 0;
        for (var machine in listenersToOpen) {
          opened++;
          _printerListeners[machine.uuid] = ref.listen(
            printerProvider(machine.uuid),
            (_, nextP) => nextP.whenData((value) => _handlePrinterData(machine.uuid, value)),
            fireImmediately: true,
          );
        }

        logger.i(
            'Added $opened new printerData listeners and removed $closed printer listeners in the LiveActivityService');
      }),
      fireImmediately: true,
    );
  }

  void _registerAppLifecycleHandler() {
    ref.listen(
      appLifecycleProvider,
      (_, next) async {
        // Force a liveActivity update once the app is back in foreground!
        if (next != AppLifecycleState.resumed) return;
        if (_disableClearing) return;
        _refreshLiveActivitiesForMachines().ignore();
      },
    );

    // Also force update on machine restart
    // Just ensure that at least the translations are available... This is kinda hacky lol
    Future.delayed(const Duration(seconds: 2)).then((value) => _refreshLiveActivitiesForMachines()).ignore();
  }

  Future<void> _handlePrinterData(String machineUUID, Printer printer) async {
    if (!await _liveActivityAPI.areActivitiesEnabled()) return;
    if (!_settingsService.readBool(AppSettingKeys.useLiveActivity, true)) return;

    if (_handlePrinterDataLocks[machineUUID]?.let((it) => !it.isCompleted) ?? false) {
      // No need to actually wait for the lock since printerData updates are really frequent skipping some is fine!
      return;
    }
    _handlePrinterDataLocks[machineUUID] = Completer();

    try {
      Notification notification =
          await _notificationsRepository.getByMachineUuid(machineUUID) ?? Notification(machineUuid: machineUUID);

      var printState = printer.print.state;
      var isPrinting = {PrintState.printing, PrintState.paused}.contains(printState);
      final hasProgressChange = isPrinting &&
          notification.progress != null && // Not sure if not.progress == null || would be better..
          ((notification.progress! - printer.printProgress) * 100).abs() > 2;
      final hasStateChange = notification.printState != printState;
      final hasFileChange =
          isPrinting && printer.currentFile?.name != null && notification.file != printer.currentFile?.name;

      final clearLiveActivity = !isPrinting && _machineLiveActivityMap.containsKey(machineUUID);

      // final hasEtaChange = isPrinting && printer.eta != null && notification.eta != printer.eta;
      if (!hasProgressChange && !hasStateChange && !hasFileChange && !clearLiveActivity) return;
      logger.i('LiveActivity Passed state and progress check. $printState, ${printer.printProgress}');
      final etaSources = _settingsService.readList<String>(AppSettingKeys.etaSources).toSet();

      await _notificationsRepository.save(
        Notification(machineUuid: machineUUID)
          ..progress = printer.printProgress
          ..eta = printer.calcEta(etaSources)
          ..file = printer.currentFile?.name
          ..printState = printer.print.state,
      );

      // No need to wait for the activity to be updated. It uses a lock to prevent to many updates at once anyway
      _refreshLiveActivity(machineUUID, printer).ignore();
    } finally {
      // Make sure in any case the lock is completed/released
      _handlePrinterDataLocks[machineUUID]!.complete();
    }
  }

  Future<void> _refreshLiveActivitiesForMachines() async {
    if (!await _liveActivityAPI.areActivitiesEnabled()) return;
    // TODO NO await, just use value or a timeout!
    List<Machine> allMachines = await ref
        .read(allMachinesProvider.future)
        .timeout(const Duration(seconds: 2))
        .catchError((_, __) => <Machine>[]);

    await _clearUnknownLiveActivities();

    logger.i('The app has currently ${allMachines.length} machines');
    for (var machine in allMachines) {
      logger.i('Force a LiveActivity update for ${machine.name} after app was resumed');
      // We await to prevent any race conditions
      ref.read(printerProvider(machine.uuid)).whenData((value) {
        if ({PrintState.printing, PrintState.paused}.contains(value.print.state)) {
          return _refreshLiveActivity(machine.uuid, value);
        }
      });
    }
  }

  Future<void> _refreshLiveActivity(String machineUUID, Printer printer) async {
    // Pseudo lock to prevent to many updates at once
    if (_updateLiveActivityLocks[machineUUID]?.let((it) => !it.isCompleted) ?? false) {
      await _updateLiveActivityLocks[machineUUID]!.future;
      return _refreshLiveActivity(machineUUID, printer);
    }
    var machine = ref.read(machineProvider(machineUUID)).valueOrNull;

    if (machine == null) return;

    logger.i('Refreshing LiveActivity for ${machine.name}');
    _updateLiveActivityLocks[machineUUID] = Completer();
    try {
      var themePack = ref.read(themeServiceProvider).activeTheme.themePack;
      final etaSources = _settingsService.readList<String>(AppSettingKeys.etaSources).toSet();
      Map<String, dynamic> data = {
        'progress': printer.printProgress,
        'state': printer.print.state.name,
        'file': printer.currentFile?.name ?? tr('general.unknown'),
        'eta': printer.calcEta(etaSources)?.secondsSinceEpoch ?? -1,

        // Not sure yet if I want to use this
        'printStartTime':
            DateTime.now().subtract(Duration(seconds: printer.print.totalDuration.toInt())).secondsSinceEpoch,

        // Labels
        'primary_color_dark': (themePack.darkTheme ?? themePack.lightTheme).colorScheme.primary.value,
        'primary_color_light': themePack.lightTheme.colorScheme.primary.value,
        'machine_name': machine.name,
        'eta_label': tr('pages.dashboard.general.print_card.eta'),
        'elapsed_label': tr('pages.dashboard.general.print_card.elapsed'),
        'remaining_label': tr('pages.dashboard.general.print_card.remaining'),
        for (var state in PrintState.values) '${state.name}_label': state.displayName,
      };

      var isPrinting = {PrintState.printing, PrintState.paused}.contains(printer.print.state);
      var isDone = {PrintState.complete, PrintState.cancelled}.contains(printer.print.state);

      if (isPrinting || isDone) {
        await _updateOrCreateLiveActivity(data, machine, isPrinting);
      } else {
        _endLiveActivity(machine);
      }
      // Sems like ther is a error in the LiveActivity API. To fast calls to the updateActivity can cause other activity to also update..
      //await Future.delayed(const Duration(milliseconds: 180));
    } finally {
      _updateLiveActivityLocks[machineUUID]!.complete();
    }
  }

  Future<void> _clearUnknownLiveActivities() async {
    logger.i('Ending all unknown LiveActivities');

    // Get all activities, if not provided
    var allActivities = await _liveActivityAPI.getAllActivities();
    logger.i('LiveactivityAPI reported ${allActivities.length} running activities');

    // Create a map that maps the activity id to the machine uuid (reverse of the local machine activity map)
    var activityIdMachine = {for (var entry in _machineLiveActivityMap.entries) entry.value.id: entry.key};

    logger.i('Found ${activityIdMachine.length} locally tracked LiveActivities');

    // Filter out all activities not known to the app -> The api/app can not address anymore

    // End them and remove them from the local machine activity map
    List<Future> endActivities = [];
    for (var activity in allActivities.entries) {
      var canBeAddressed = activity.value == LiveActivityState.active || activity.value == LiveActivityState.stale;
      if (canBeAddressed && activityIdMachine.containsKey(activity.key)) continue;

      endActivities.add(_liveActivityAPI.endActivity(activity.key));

      var machineId = activityIdMachine[activity.key];
      if (machineId != null) _machineLiveActivityMap.remove(machineId);
    }

    // Ensure we wait for all activities to be ended
    await Future.wait(endActivities);
    logger.i('Cleared unknown LiveActivities, total ended: ${endActivities.length}');
    _backupLiveActivityMap();
  }

  Future<String?> _updateOrCreateLiveActivity(Map<String, dynamic> activityData, Machine machine,
      [bool createIfMissing = true]) async {
    // API handles both updating and creating
    var activityId =
        await _liveActivityAPI.createOrUpdateActivity(machine.uuid, activityData, removeWhenAppIsKilled: true);

    if (activityId case String()) {
      _machineLiveActivityMap[machine.uuid] = _ActivityEntry(activityId);
      logger.i('Created new LiveActivity for ${machine.name} with id: $activityId');
      return activityId;
    }
    logger.i('Updated LiveActivity for ${machine.name}');
    return null;
  }

  _endLiveActivity(Machine machine) {
    _machineLiveActivityMap.remove(machine.uuid)?.let((x) => _liveActivityAPI.endActivity(x.id));
    _machineService.updateMachineFcmLiveActivity(machine: machine).ignore();
    _backupLiveActivityMap();
  }

  _backupLiveActivityMap() {
    _settingsService.writeMap(
        UtilityKeys.liveActivityStore, _machineLiveActivityMap.map((key, value) => MapEntry(key, value.id)));
  }

  _restoreActivityMap() async {
    _machineLiveActivityMap.clear();
    // Get all current activity ids
    Map<String, LiveActivityState> createdActivities = await _liveActivityAPI.getAllActivities();

    // Get the last known mapping of machine uuid to activity id
    var lastMappings = _settingsService.readMap<String, String>(UtilityKeys.liveActivityStore);

    // Filter out all mappings that are not in the current activity ids and are not active or stale
    var updatedMappings = {
      for (var entry in lastMappings.entries)
        if (createdActivities[entry.value] case (LiveActivityState.active || LiveActivityState.stale))
          entry.key: _ActivityEntry(entry.value)
    };

    _machineLiveActivityMap.addAll(updatedMappings);
    logger.i('Restored ${updatedMappings.length} LiveActivities from storage: $lastMappings');
    _backupLiveActivityMap();

    // Close all activities for which we could not find a mapping
    _clearUnknownLiveActivities();
  }

  dispose() {
    logger.e('The LiveActivityService was disposed! THIS SHOULD NEVER HAPPEN! CHECK THE DISPOSING!!!');
    _machineUpdatesListener?.cancel();
    _activityUpdateStreamSubscription?.cancel();
    for (var element in _printerListeners.values) {
      element.close();
    }
  }

  disableClearing() {
    _disableClearing = true;
  }
}

class _ActivityEntry {
  _ActivityEntry(this.id, [this.pushToken]);

  String id;
  String? pushToken;

  @override
  String toString() {
    return '_ActivityEntry{id: $id, pushToken: $pushToken}';
  }
}
