/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/util/extensions/date_time_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/activity_update.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/dto/machine/print_state_enum.dart';
import '../data/dto/machine/printer.dart';
import 'live_activity_service.dart';
import 'misc_providers.dart';
import 'moonraker/printer_service.dart';

part 'live_activity_service_v2.g.dart';

@riverpod
LiveActivityServiceV2 v2LiveActivity(V2LiveActivityRef ref) {
  ref.keepAlive();
  return LiveActivityServiceV2(ref);
}

class LiveActivityServiceV2 {
  LiveActivityServiceV2(this.ref)
      : _machineService = ref.watch(machineServiceProvider),
        _settingsService = ref.watch(settingServiceProvider),
        _liveActivityAPI = ref.watch(liveActivityProvider) {
    ref.onDispose(dispose);
  }

  final AutoDisposeRef ref;
  final MachineService _machineService;
  final SettingService _settingsService;
  final LiveActivities _liveActivityAPI;

  final Map<String, _ActivityEntry> _activityData = {};
  final Map<String, ProviderSubscription<AsyncValue<Printer>>> _printerDataListeners = {};

  final List<StreamSubscription> _subscriptions = [];

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (!Platform.isIOS) {
        logger.i('LiveActivityService is only available on iOS. Skipping initialization.');
        return;
      }
      logger.i('Starting LiveActivityService init');

      try {
        await _init();
        logger.i('Completed LiveActivityService init');
      } catch (e, s) {
        FirebaseCrashlytics.instance.recordError(
          e,
          s,
          reason: 'Error while setting up the LiveActivityService',
          fatal: true,
        );
        logger.w('Unexpected error while initializing LiveActivityService.', e, s);
      }
    } finally {
      _initialized = true;
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

  /// Responsible for syncing the push token (APNs token) from the platform to this service.
  void _setupLiveActivityListener() {
    logger.i('Setting up LiveActivity listener');
    final s = _liveActivityAPI.activityUpdateStream.listen((event) async {
      logger.i('LiveActivity update: $event');

      switch (event) {
        case ActiveActivityUpdate():
          logger.i('Received activity push token update for ${event.activityId} with token ${event.activityToken}');
          final entry =
              _activityData.entries.firstWhereOrNull((element) => element.value.activityId == event.activityId);
          if (entry == null) {
            logger.w('Received push token update for unknown activity ${event.activityId}');
            return;
          }
          logger.i('Update is for machine ${entry.key}');
          // Track in this service
          _writeToMap(entry.key, entry.value.copyWith(pushToken: event.activityToken));

          // We also need to sync that token to the machine to be able to send push notifications/updates
          _machineService.updateApplePushNotificationToken(entry.key, event.activityToken).ignore();
          logger.i('Updated push token for activity ${event.activityId} to ${event.activityToken}');
          break;
        case EndedActivityUpdate():
          logger.i('Received activity ended update for ${event.activityId}');
          _activityData.removeWhere((key, value) => value.activityId == event.activityId);
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

    //TODO: also force a refresh directly here?

    // Just ensure that at least the translations are available... This is kinda hacky lol
    // Future.delayed(const Duration(seconds: 2)).then((value) => _refreshLiveActivitiesForMachines()).ignore();
  }

  /// Refreshes the live activities for all machines.
  Future<void> _refreshActivities() async {
    logger.i('Refreshing live activities');
    try {
      var allMachs = await ref.read(allMachinesProvider.future);
      for (var machine in allMachs) {
        await _dummyForId(machine.uuid);
      }
    } finally {
      logger.i('Finished refreshing live activities');
    }
  }

  Future<void> _handlePrinterData(String machineUUID, Printer printer) async {
    //TODO: Actually handle the printer data here, for now just dummy code for creating an activity

    // logger.i('Handling printer data for machine $machineUUID');
    try {
      if (printer.print.state != PrintState.printing) {
        // logger.i('Printer is not printing. Skipping activity creation/updates.');
        return;
      }
      _dummyForId(machineUUID);
    } finally {
      // logger.i('Finished handling printer data for machine $machineUUID');
    }
  }

  void _writeToMap(String key, _ActivityEntry entry) {
    _activityData[key] = entry;
    _backupActivityData();
  }

  void _backupActivityData() {
    // Backup the activity data to the machine service
    //TODO: Cant write _ActivityEntry directly. Only primitives are allowed (Or Map Entry)
    // _settingsService.writeMap(UtilityKeys.liveActivityStore, _activityData);
  }

  void _restoreActivityData() {
    final data = _settingsService.readMap<String, _ActivityEntry>(UtilityKeys.liveActivityStore);
    _activityData.addAll(data);
  }

  Future<void> _dummyForId(String machineUUID) async {
    logger.i('Creating dummy activity for machine $machineUUID');
    // For now this is just dummy code to test the content...
    final enabled = await _liveActivityAPI.areActivitiesEnabled();
    final allIds = await _liveActivityAPI.getAllActivities();
    logger.i('Live activities are enabled: $enabled');
    logger.i('All activities: $allIds');

    final _liveActivityIdForMachine = _activityData[machineUUID]?.activityId;

    Map<String, dynamic> data = {
      'progress': 0.25,
      'state': PrintState.printing.name,
      'file': '${allIds.length}x Ids, ${DateTime.now().toIso8601String()}',
      'eta': -1,

      // Not sure yet if I want to use this
      'printStartTime': DateTime.now().subtract(Duration(seconds: 5000)).secondsSinceEpoch,

      // Labels
      'primary_color_dark': Colors.yellow.value,
      'primary_color_light': Colors.pinkAccent.value,
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
