/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:common/data/model/hive/notification.dart';
import 'package:common/service/firebase/remote_config.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/util/extensions/date_time_extension.dart';
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

const int PRINTER_DATA_REFRESH_INTERVAL = 5; // SECONDS

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

      final all = await _liveActivityAPI.getAllActivitiesIds();
      logger.i('Found ${all.length} active activities. Ending all of them.');
      await _liveActivityAPI.endAllActivities();

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
          _machineActivityMapping[entry.key] = entry.value.copyWith(pushToken: event.activityToken);

          // We also need to sync that token to the machine to be able to send push notifications/updates
          _machineService.updateApplePushNotificationToken(entry.key, event.activityToken).ignore();
          logger.i('Updated push token for activity ${event.activityId} to ${event.activityToken}');
          break;
        case EndedActivityUpdate():
          logger.i('Received activity ended update for ${event.activityId}');
          final entry = _machineActivityMapping.entries
              .firstWhereOrNull((element) => element.value.activityId == event.activityId);
          if (entry == null) {
            logger.w('Received ended activity update for unknown activity ${event.activityId}');
            return;
          }
          _machineService.updateApplePushNotificationToken(entry.key, null).ignore();
          _machineActivityMapping.remove(entry.key);
          break;
        default:
          logger.w('Received unknown activity update: $event');
      }
    });
    _subscriptions.add(s);
  }

  /// Setups the listeners for the printer data for all machines.
  void _setupPrinterDataListeners() {
    logger.i('Setting up printerData listeners');
    ref.listen(
      allMachinesProvider,
      (_, next) => next.whenData((machines) {
        final listenersToOpen = machines.whereNot((e) => _printerDataListeners.containsKey(e.uuid)).toList();
        final listenersToClose = _printerDataListeners.keys.whereNot((e) => machines.any((m) => m.uuid == e)).toList();

        for (var uuid in listenersToClose) {
          _printerDataListeners[uuid]?.close();
          _printerDataListeners.remove(uuid);
        }

        for (var machine in listenersToOpen) {
          _printerDataListeners[machine.uuid] = ref.listen(
            printerProvider(machine.uuid),
            (_, nextP) => nextP.whenData((value) => _handlePrinterData(machine.uuid, value).ignore()),
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
        if (next != AppLifecycleState.resumed) return;
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
        // Get the printer data and use it to refresh the live activity via the handlePrinterData method
        final res = ref
            .read(printerProvider(machine.uuid).future)
            .then((value) => _handlePrinterData(machine.uuid, value).ignore());
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
    final lock = Completer();
    _handlePrinterDataThrottleLocks[machineUUID] = lock;
    try {
      final notification =
          await _notificationsRepository.getByMachineUuid(machineUUID) ?? Notification(machineUuid: machineUUID);

      final etaSources = _settingsService.readList<String>(AppSettingKeys.etaSources).toSet();

      // Data that needs to be present to be shown!
      final hasDataReady = printer.currentFile?.name != null;

      // Conditions for a refresh based on the printer data
      final printState = printer.print.state;
      final isPrinting = {PrintState.printing, PrintState.paused}.contains(printState);
      final hasProgressChange = isPrinting &&
          (notification.progress == null || ((notification.progress! - printer.printProgress) * 100).abs() > 2);
      final hasStateChange = notification.printState != printState;
      final hasFileChange =
          isPrinting && printer.currentFile?.name != null && notification.file != printer.currentFile?.name;

      // We use the slicer estimate to get a delta window. If the delta is more than 5% of the estimated time or 15 minutes we update the ETA. (Whichever is higher)
      final deltaWindow = max((printer.currentFile?.estimatedTime?.let((it) => (it * 0.05) ~/ 60)) ?? 15, 15);
      final eta = printer.calcEta(etaSources);
      final hasEtaChange = isPrinting &&
          eta != null &&
          (notification.eta == null || eta.difference(notification.eta!).inMinutes.abs() >= deltaWindow);

      // Check if we need to create or clear the live activity
      final createLiveActivity = isPrinting && !_machineActivityMapping.containsKey(machineUUID);
      final clearLiveActivity = !isPrinting && _machineActivityMapping.containsKey(machineUUID);

      // logger.i('Progress: $hasProgressChange, State: $hasStateChange, File: $hasFileChange, ETA: $hasEtaChange, Clear: $clearLiveActivity, Create: $createLiveActivity, Delta: $deltaWindow');
      if (!hasDataReady ||
          !createLiveActivity &&
              !clearLiveActivity &&
              !hasProgressChange &&
              !hasStateChange &&
              !hasFileChange &&
              !hasEtaChange) return;
      // logger.i('Passed the refresh check for machine $machineUUID (Progress: $hasProgressChange, State: $hasStateChange, File: $hasFileChange, ETA: $hasEtaChange, Clear: $clearLiveActivity, Create: $createLiveActivity)');
      final activityChanged = await _refreshLiveActivityForMachine(machineUUID, printer);

      // Save the notification data if the activity was changed
      if (activityChanged) {
        await _notificationsRepository.save(
          Notification(machineUuid: machineUUID)
            ..progress = printer.printProgress
            ..eta = eta
            ..file = printer.currentFile?.name
            ..printState = printer.print.state,
        );
      }
    } finally {
      // Need to do it like that because nothing is awaiting the actual completer!
      await Future.delayed(const Duration(seconds: PRINTER_DATA_REFRESH_INTERVAL));
      lock.complete();
    }
  }

  /// Refreshes the live activity or a machine (Creates or updates the activity)
  /// It does not check if a refresh is needed. It just creates/updates the activity.
  /// This method is also responsible for removing the activity if the printer is not printing or paused.
  /// Returns true if the activity was created, updated or removed and false if nothing was done.
  Future<bool> _refreshLiveActivityForMachine(String machineUUID, Printer printer) async {
    Completer? lock;
    try {
      int tries = 0;
      // Check lock -> We do it in a loop. This is because we want to enusre our Task is not listening to an to old future.
      while ((_refreshActivityLocks[machineUUID]?.let((it) => !it.isCompleted) ?? false) && tries < 5) {
        // Wait for the lock to be completed
        await _refreshActivityLocks[machineUUID]!.future;
        tries++;
      }
      if (tries >= 5) {
        logger.w('Could not acquire lock for machine $machineUUID. Skipping activity refresh.');
        return false;
      }

      // Acquire lock
      lock = Completer();
      _refreshActivityLocks[machineUUID] = lock;

      // Get machine data
      final machine = await ref.read(machineProvider(machineUUID).future);
      if (machine == null) return false;

      // logger.i('Refreshing live activity for machine ${machine.logNameExtended}');
      final themePack = ref.read(themeServiceProvider).activeTheme.themePack;
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

      if (isPrinting) {
        await _updateOrCreateLiveActivity(data, machineUUID);
      } else {
        // Only remove the activity if the app is not in the resumed state -> This is to prevent the activity from being removed when the app is in the background and usefull for the user to see
        if (ref.read(appLifecycleProvider) != AppLifecycleState.resumed) {
          logger.i('App is not in resumed state. Skipping activity removal for machine $machineUUID');
          return false;
        }
        final activity = _machineActivityMapping.remove(machineUUID);
        // Remove the activity if the printer is not printing or paused
        if (activity != null && ref.read(remoteConfigBoolProvider('clear_live_activity_on_done'))) {
          _liveActivityAPI.endActivity(activity.activityId).ignore();
        }

        // Also remove the push token from the machine
        _machineService.updateApplePushNotificationToken(machineUUID, null);
      }
      return true;
    } finally {
      // Release lock if acquired
      lock?.complete();
    }
  }

  /// Updates or creates a live activity for a machine.
  /// Note that this does not require a lock as it is part of the refreshLiveActivityForMachine method which already has a lock.
  Future<String?> _updateOrCreateLiveActivity(Map<String, dynamic> activityData, String machineUUID) async {
    // Get platform info about the current active activities
    final activeCount = await _liveActivityAPI.getAllActivitiesIds().then((value) => value.length);
    if (activeCount >= 5) {
      logger.w('Cannot create new LiveActivity for $machineUUID. Too many activities are already active.');
      return null;
    }

    // Okay I guess we need to create a new activity for this machine
    final activityId =
        await _liveActivityAPI.createOrUpdateActivity(machineUUID, activityData, removeWhenAppIsKilled: true);
    if (activityId case String()) {
      _machineActivityMapping[machineUUID] = _ActivityEntry(activityId);
      logger.i('Created new LiveActivity for $machineUUID} with id: $activityId');
      return activityId;
    }

    logger.i('Updated LiveActivity for $machineUUID');
    return activityId;
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
