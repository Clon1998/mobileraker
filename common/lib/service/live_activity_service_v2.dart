/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:io' show Platform;

import 'package:collection/collection.dart';
import 'package:common/data/model/hive/notification.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/util/extensions/date_time_extension.dart';
import 'package:common/util/extensions/logging_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/activity_update.dart';
import 'package:live_activities/models/live_activity_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/dto/machine/print_state_enum.dart';
import '../data/dto/machine/printer.dart';
import '../data/repository/notifications_hive_repository.dart';
import '../data/repository/notifications_repository.dart';
import 'live_activity_service.dart';
import 'misc_providers.dart';
import 'moonraker/printer_service.dart';
import 'ui/theme_service.dart';

part 'live_activity_service_v2.g.dart';

const int PRINTER_DATA_REFRESH_INTERVAL = 30; // SECONDS

@riverpod
LiveActivityServiceV2 v2LiveActivity(V2LiveActivityRef ref) {
  ref.keepAlive();
  return LiveActivityServiceV2(ref);
}

class LiveActivityServiceV2 {
  LiveActivityServiceV2(this.ref)
      : _machineService = ref.watch(machineServiceProvider),
        _settingsService = ref.watch(settingServiceProvider),
        _liveActivityAPI = ref.watch(liveActivityProvider),
        _notificationsRepository = ref.watch(notificationRepositoryProvider) {
    ref.onDispose(dispose);
  }

  final AutoDisposeRef ref;
  final MachineService _machineService;
  final SettingService _settingsService;
  final LiveActivities _liveActivityAPI;
  final NotificationsRepository _notificationsRepository;

  final Map<String, _ActivityEntry> _machineActivityMapping = {};
  final Map<String, ProviderSubscription<AsyncValue<Printer>>> _printerDataListeners = {};

  final Map<String, Completer?> _refreshActivityLocks = {};
  final Map<String, Completer?> _handlePrinterDataThrottleLocks = {}; // Throttle lock for printer data updates
  final List<StreamSubscription> _subscriptions = [];

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true; // Move this line here to prevent race conditions
    try {
      if (!Platform.isIOS) {
        logger.i('LiveActivityService is only available on iOS. Skipping initialization.');
        return;
      }
      logger.i('Starting LiveActivityService init');
      await _init();
      logger.i('Completed LiveActivityService init');
    } catch (e, s) {
      FirebaseCrashlytics.instance
          .recordError(e, s, reason: 'Error while setting up the LiveActivityService', fatal: true);
      logger.w('Unexpected error while initializing LiveActivityService.', e, s);
    }
  }

  Future<void> _init() async {
    try {
      logger.i('Connecting with Platform live_activity');
      await _liveActivityAPI.init(appGroupId: 'group.mobileraker.liveactivity');

      _setupLiveActivityListener();
      _setupPrinterDataListeners();
      _registerAppLifecycleHandler();
    } catch (e, s) {
      if (e is PlatformException) {
        if (e.code == 'WRONG_IOS_VERSION') {
          logger.w('Failed to initialize LiveActivityService. The current iOS version is not supported.');
          return;
        }
      }
      rethrow;
    }
  }

  /// Responsible for syncing the push token (APNs token) from the platform to this service and the machine service.
  void _setupLiveActivityListener() {
    logger.i('Setting up LiveActivity listener');
    final s = _liveActivityAPI.activityUpdateStream.listen((event) async {
      switch (event) {
        case ActiveActivityUpdate():
          logger.i('Received activity push token update for ${event.activityId} with token ${event.activityToken}');
          final entry = _machineActivityMapping.entries
              .firstWhereOrNull((element) => element.value.activityId == event.activityId);

          if (entry == null) {
            logger.w('Received push token update for unknown activity ${event.activityId}');
            return;
          }
          if (entry.value.pushToken == event.activityToken) {
            logger.i('Push token for activity ${event.activityId} is already up to date');
            return;
          }

          logger.i('LiveActivity update is for machine ${entry.key}');
          // Track in this service
          _writeToMap(entry.key, entry.value.copyWith(pushToken: event.activityToken));

          // We also need to sync that token to the machine to be able to send push notifications/updates
          _machineService.updateApplePushNotificationToken(entry.key, event.activityToken).ignore();
          logger.i('Updated push token for activity ${event.activityId} to ${event.activityToken}');
          break;
        case EndedActivityUpdate():
          logger.i('Received activity ended update for ${event.activityId}');
          _machineActivityMapping.removeWhere((key, value) => value.activityId == event.activityId);
          _machineService.updateApplePushNotificationToken(event.activityId, null).ignore();
          break;
      }
    });
    _subscriptions.add(s);
  }

  /// Setups the listeners for the printer data for all machines.
  void _setupPrinterDataListeners() {
    ref.listen(
      allMachinesProvider,
      (_, next) => next.whenData((machines) {
        final listenersToOpen = machines.whereNot((e) => _printerDataListeners.containsKey(e.uuid));
        final listenersToClose = _printerDataListeners.keys.whereNot((e) => machines.any((m) => m.uuid == e));

        for (var uuid in listenersToClose) {
          _printerDataListeners[uuid]?.close();
          _printerDataListeners.remove(uuid);
        }

        for (var machine in listenersToOpen) {
          _printerDataListeners[machine.uuid] = ref.listen(
            printerProvider(machine.uuid),
            (_, nextP) => nextP.whenData((value) => _handlePrinterData(machine.uuid, value)),
            fireImmediately: true,
          );
        }

        logger.i(
            'Added ${listenersToOpen.length} new printerData listeners and removed ${listenersToClose.length} printer listeners in the LiveActivityService');
      }),
      fireImmediately: true,
    );
  }

  /// Do a check if we need to refresh the live activities for all machines when the app is resumed.
  void _registerAppLifecycleHandler() {
    logger.i('Registering AppLifecycle handler');
    ref.listen(
      appLifecycleProvider,
      (_, next) async {
        // Only force a refresh for all machines when the app is resumed
        // if (next != AppLifecycleState.resumed) return;
        //TODO: THIS IS FOR DEV only
        if (next != AppLifecycleState.inactive) return;
        _refreshActivities().ignore();
      },
    );
  }

  /// Refreshes the live activities for all machines.
  Future<void> _refreshActivities() async {
    logger.i('Refreshing live activities');
    try {
      final toWaitFor = <Future>[];
      final allMachs = await ref.read(allMachinesProvider.future);
      for (var machine in allMachs) {
        // await _dummyForId(machine.uuid);

        // Get the printer data and use it to refresh the live activity via the handlePrinterData method
        final res =
            ref.read(printerProvider(machine.uuid).future).then((value) => _handlePrinterData(machine.uuid, value));
        toWaitFor.add(res);
      }
      await Future.wait(toWaitFor);
    } finally {
      logger.i('Finished refreshing live activities');
    }
  }

  Future<void> _handlePrinterData(String machineUUID, Printer printer) async {
    if (!await _liveActivityAPI.areActivitiesEnabled()) return;
    if (!_settingsService.readBool(AppSettingKeys.useLiveActivity, true)) return;

    // Use locks to prevent multiple async updates at the same time
    // No need to actually wait for the lock since printerData updates are really frequent skipping some is fine!
    if (_handlePrinterDataThrottleLocks[machineUUID]?.let((it) => !it.isCompleted) ?? false) return;
    _handlePrinterDataThrottleLocks[machineUUID] = Completer();

    try {
      final notification =
          await _notificationsRepository.getByMachineUuid(machineUUID) ?? Notification(machineUuid: machineUUID);

      final printState = printer.print.state;
      final isPrinting = {PrintState.printing, PrintState.paused}.contains(printState);
      final hasProgressChange = isPrinting &&
          (notification.progress == null || ((notification.progress! - printer.printProgress) * 100).abs() > 2);

      final hasStateChange = notification.printState != printState;
      final hasFileChange =
          isPrinting && printer.currentFile?.name != null && notification.file != printer.currentFile?.name;

      // Also update of the ETA is unset, more than 15 minutes off but only if we are printing
      final hasEtaChange = isPrinting &&
          printer.eta != null &&
          (notification.eta == null || printer.eta!.difference(notification.eta!).inMinutes.abs() >= 15);

      final clearLiveActivity = !isPrinting && _machineActivityMapping.containsKey(machineUUID);

      if (!hasProgressChange && !hasStateChange && !hasFileChange && !hasEtaChange && !clearLiveActivity) return;
      logger.i(
          'Passed the refresh check for machine $machineUUID (Progress: $hasProgressChange, State: $hasStateChange, File: $hasFileChange, ETA: $hasEtaChange)');
      await _notificationsRepository.save(
        Notification(machineUuid: machineUUID)
          ..progress = printer.printProgress
          ..eta = printer.eta
          ..file = printer.currentFile?.name
          ..printState = printer.print.state,
      );

      await _refreshLiveActivityForMachine(machineUUID, printer);
    } finally {
      // Release the lock with a delay to prevent too frequent updates (Throttle)
      _handlePrinterDataThrottleLocks[machineUUID]
          ?.complete(Future.delayed(const Duration(seconds: PRINTER_DATA_REFRESH_INTERVAL)));
    }
  }

  /// Refreshes the live activity or a machine (Creates or updates the activity)
  /// It does not check if a refresh is needed. It just creates/updates the activity.
  Future<void> _refreshLiveActivityForMachine(String machineUUID, Printer printer) async {
    _refreshActivityLocks[machineUUID] ??= Completer();
    Completer? lock;
    try {
      // Check lock
      if (_refreshActivityLocks[machineUUID]?.let((it) => !it.isCompleted) ?? false) {
        // Wait for the lock to be completed
        await _refreshActivityLocks[machineUUID]!.future;
      }
      // Acquire lock
      lock = Completer();
      _refreshActivityLocks[machineUUID] = lock;

      // Get machine data
      final machine = await ref.read(machineProvider(machineUUID).future);
      if (machine == null) return;

      logger.i('Refreshing live activity for machine ${machine.logNameExtended}');
      var themePack = ref.read(themeServiceProvider).activeTheme.themePack;
      Map<String, dynamic> data = {
        'progress': printer.printProgress,
        'state': printer.print.state.name,
        'file': printer.currentFile?.name ?? tr('general.unknown'),
        'eta': printer.eta?.secondsSinceEpoch ?? -1,

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
        'completed_label': tr('general.completed'),
      };

      var isPrinting = {PrintState.printing, PrintState.paused}.contains(printer.print.state);
      var isDone = {PrintState.complete, PrintState.cancelled}.contains(printer.print.state);

      if (isPrinting || isDone) {
        await _updateOrCreateLiveActivity(data, machineUUID);
      } else {
        // Remove the activity if the printer is not printing or paused
        _removeFromMap(machineUUID)?.also((it) => _liveActivityAPI.endActivity(it.activityId).ignore());
        // Also remove the push token from the machine
        _machineService.updateApplePushNotificationToken(machineUUID, null);
      }
    } finally {
      // Release lock if acquired
      lock?.complete();
    }
  }

  /// Updates or creates a live activity for a machine.
  /// Note that this does not require a lock as it is part of the refreshLiveActivityForMachine method which already has a lock.
  Future<String?> _updateOrCreateLiveActivity(Map<String, dynamic> activityData, String machineUUID) async {
    // Check if an activity is already running for this machine and if we can still address it
    if (_machineActivityMapping.containsKey(machineUUID)) {
      _ActivityEntry activityEntry = _machineActivityMapping[machineUUID]!;

      LiveActivityState? activityState = await _liveActivityAPI.getActivityState(activityEntry.activityId);

      logger.i('Found a live activity for $machineUUID with state: $activityState');

      // If the activity is still active we can update it and return
      if (activityState == LiveActivityState.active) {
        logger.i('Can update LiveActivity for $machineUUID with id: $activityEntry');
        await _liveActivityAPI.updateActivity(activityEntry.activityId, activityData);
        return activityEntry.activityId;
      }
      // Okay we can not update the activity remove and end it
      await _liveActivityAPI.endActivity(activityEntry.activityId);
      _removeFromMap(machineUUID);
    }

    // Get platform info about the current active activities
    final activeCount = await _liveActivityAPI.getAllActivitiesIds().then((value) => value.length);
    if (activeCount >= 5) {
      logger.w('Cannot create new LiveActivity for $machineUUID. Too many activities are already active.');
      return null;
    }

    // Okay I guess we need to create a new activity for this machine
    final activityId = await _liveActivityAPI.createActivity(activityData, removeWhenAppIsKilled: true);
    if (activityId != null) {
      _writeToMap(machineUUID, _ActivityEntry(activityId));
    }
    logger.i('Created new LiveActivity for $machineUUID with id: $activityId');
    return activityId;
  }

  void _writeToMap(String key, _ActivityEntry entry) {
    _machineActivityMapping[key] = entry;
    _backupActivityData();
  }

  _ActivityEntry? _removeFromMap(String key) {
    final t = _machineActivityMapping.remove(key);
    _backupActivityData();
    return t;
  }

  void _backupActivityData() {
    // Backup the activity data to the machine service
    //TODO: Cant write _ActivityEntry directly. Only primitives are allowed (Or Map Entry)
    // _settingsService.writeMap(UtilityKeys.liveActivityStore, _activityData);
  }

  void _restoreActivityData() {
    final data = _settingsService.readMap<String, _ActivityEntry>(UtilityKeys.liveActivityStore);
    _machineActivityMapping.addAll(data);
  }

  Future<void> _dummyForId(String machineUUID) async {
    logger.i('Creating dummy activity for machine $machineUUID');
    // For now this is just dummy code to test the content...
    final enabled = await _liveActivityAPI.areActivitiesEnabled();
    final allIds = await _liveActivityAPI.getAllActivities();
    logger.i('Live activities are enabled: $enabled');
    logger.i('All activities: $allIds');

    final _liveActivityIdForMachine = _machineActivityMapping[machineUUID]?.activityId;

    Map<String, dynamic> data = {
      'progress': 0.25,
      'state': PrintState.printing.name,
      'file': '${allIds.length}x Ids, ${DateTime.now().toIso8601String()}',
      'eta': -1,

      // Not sure yet if I want to use this
      'printStartTime': DateTime.now().subtract(const Duration(seconds: 5000)).secondsSinceEpoch,

      // Labels
      'primary_color_dark': 0xFFFFEB3B,
      'primary_color_light': 0xFFFF4081,
      'machine_name': '$machineUUID ${_liveActivityIdForMachine ?? '---'}',
      'eta_label': tr('pages.dashboard.general.print_card.eta'),
      'elapsed_label': tr('pages.dashboard.general.print_card.elapsed'),
      'remaining_label': tr('pages.dashboard.general.print_card.remaining'),
      'completed_label': tr('general.completed'),
    };

    if (_liveActivityIdForMachine == null) {
      final id = await _liveActivityAPI.createActivity(data, removeWhenAppIsKilled: true);
      if (id == null) {
        logger.e('Failed to create activity');
        return;
      }
      logger.i('Created activity with id: $id');
      _writeToMap(machineUUID, _ActivityEntry(id));
    } else {
      _liveActivityAPI.updateActivity(_liveActivityIdForMachine, data);
    }
  }

  void dispose() {
    logger.e('The LiveActivityService was disposed! THIS SHOULD NEVER HAPPEN! CHECK THE DISPOSING!!!');
    for (var element in _subscriptions) {
      element.cancel();
    }

    _printerDataListeners.forEach((key, value) {
      value.close();
    });

    // Clear all locks
    _refreshActivityLocks.forEach((key, value) {
      value?.completeError('Service was disposed');
    });
    _handlePrinterDataThrottleLocks.forEach((key, value) {
      value?.completeError('Service was disposed');
    });
  }
}

@immutable
class _ActivityEntry {
  const _ActivityEntry(this.activityId, {this.pushToken});

  final String activityId;
  final String? pushToken;

  _ActivityEntry copyWith({String? activityId, String? pushToken}) {
    return _ActivityEntry(
      activityId ?? this.activityId,
      pushToken: pushToken ?? this.pushToken,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ActivityEntry &&
            (identical(other.activityId, activityId) || other.activityId == activityId) &&
            (identical(other.pushToken, pushToken) || other.pushToken == pushToken));
  }

  @override
  int get hashCode => Object.hash(activityId, pushToken);
}
