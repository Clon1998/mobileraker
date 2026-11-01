/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:common/data/enums/eta_data_source.dart';
import 'package:common/data/model/hive/notification.dart';
import 'package:common/network/dio_provider.dart';
import 'package:common/service/firebase/remote_config.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/util/extensions/date_time_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/dto/files/gcode_file.dart';
import '../data/dto/machine/print_state_enum.dart';
import '../data/dto/machine/printer.dart';
import '../data/repository/notifications_hive_repository.dart';
import '../data/repository/notifications_repository.dart';
import 'live_activity/live_activity_api.pigeon.dart';
import 'misc_providers.dart';
import 'moonraker/printer_service.dart';
import 'ui/theme_service.dart';

part 'live_activity_service_v2.g.dart';

const int PRINTER_DATA_REFRESH_INTERVAL = 5; // SECONDS

@Riverpod(keepAlive: true)
LiveActivityHostApi liveActivityHostApi(Ref ref) {
  return LiveActivityHostApi();
}


@riverpod
LiveActivityServiceV2 v2LiveActivity(Ref ref) {
  ref.keepAlive();
  return LiveActivityServiceV2(ref);
}

class LiveActivityServiceV2 {
  LiveActivityServiceV2(this.ref)
      : _machineService = ref.watch(machineServiceProvider),
        _settingsService = ref.watch(settingServiceProvider),
        _liveActivityAPI = ref.watch(liveActivityHostApiProvider),
        _notificationsRepository = ref.watch(notificationRepositoryProvider) {
    ref.onDispose(dispose);
  }

  final Ref ref;
  final MachineService _machineService;
  final SettingService _settingsService;
  final LiveActivityHostApi _liveActivityAPI;
  final NotificationsRepository _notificationsRepository;

  final Map<String, _ActivityEntry> _machineActivityMapping = {};
  final Map<String, ProviderSubscription<AsyncValue<Printer>>> _printerDataListeners = {};

  /// Machine UUID -> file name of the thumbnail that was stored for the widget
  final Map<String, String> _thumbnailFiles = {};

  final Map<String, Completer?> _refreshActivityLocks = {};
  final Map<String, Completer?> _handlePrinterDataThrottleLocks = {}; // Throttle lock for printer data updates
  final List<StreamSubscription> _subscriptions = [];

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true; // Move this line here to prevent race conditions
    try {
      if (!Platform.isIOS) {
        talker.info('LiveActivityService is only available on iOS. Skipping initialization.');
        return;
      }
      talker.info('Starting LiveActivityService init');
      await _init();
      talker.info('Completed LiveActivityService init');
    } catch (e, s) {
      FirebaseCrashlytics.instance
          .recordError(e, s, reason: 'Error while setting up the LiveActivityService', fatal: true);
      talker.warning('Unexpected error while initializing LiveActivityService.', e, s);
    }
  }

  Future<void> _init() async {
    talker.info('Connecting with native LiveActivityBridge');
    await _restoreActivities();
    _setupLiveActivityListener();
    _setupPrinterDataListeners();
    _registerAppLifecycleHandler();
  }

  /// Re-adopts the activities that are still running from a previous app session.
  /// Activities are identified via their machine UUID, so there is no need to end them on startup.
  Future<void> _restoreActivities() async {
    final machines = await ref.read(allMachinesProvider.future);
    // Ends activities of deleted machines and the ones created by older app versions (no machine UUID)
    await _liveActivityAPI.endAllExcept(machines.map((e) => e.uuid).toList());

    final activities = await _liveActivityAPI.getActivities();
    for (final activity in activities) {
      final machineUUID = activity.machineUUID;
      if (machineUUID == null || !_isRunning(activity.state)) continue;
      // The push token is synced to the machine once the event stream replays it
      _machineActivityMapping[machineUUID] = _ActivityEntry(activity.activityId);
    }
    talker.info('Restored ${_machineActivityMapping.length} running live activities');
  }

  bool _isRunning(LiveActivityStateMessage state) =>
      state == LiveActivityStateMessage.active || state == LiveActivityStateMessage.stale;

  /// Responsible for syncing the push token (APNs token) from the platform to this service and the machine service.
  void _setupLiveActivityListener() {
    talker.info('Setting up LiveActivity listener');
    final s = liveActivityEvents().listen((event) {
      switch (event) {
        case LiveActivityTokenEvent(:final machineUUID?):
          talker.info('Received activity push token update for ${event.activityId} with token ${event.token}');
          final entry = _machineActivityMapping[machineUUID];
          if (entry?.activityId == event.activityId && entry?.pushToken == event.token) {
            talker.info('Push token for activity ${event.activityId} is already up to date');
            return;
          }

          talker.info('LiveActivity update is for machine $machineUUID');
          if (ref.read(allMachinesProvider).value?.none((e) => e.uuid == machineUUID) ?? true) {
            talker.warning('Received push token for activity of unknown machine $machineUUID. Not syncing it.');
            return;
          }
          // Track in this service
          _machineActivityMapping[machineUUID] = _ActivityEntry(event.activityId, pushToken: event.token);

          // We also need to sync that token to the machine to be able to send push notifications/updates
          _machineService.updateApplePushNotificationToken(machineUUID, event.token).ignore();
          talker.info('Updated push token for activity ${event.activityId} to ${event.token}');
        case LiveActivityStateEvent(:final machineUUID?, :final state) when !_isRunning(state):
          talker.info('Received activity ended update for ${event.activityId}');
          if (_machineActivityMapping[machineUUID]?.activityId != event.activityId) {
            talker.info('Ended activity ${event.activityId} is not the current activity of machine $machineUUID');
            return;
          }
          _machineService.updateApplePushNotificationToken(machineUUID, null).ignore();
          _machineActivityMapping.remove(machineUUID);
        case LiveActivityPushToStartTokenEvent():
          // Not synced anywhere yet, remote start is not implemented. Logged to allow manual testing.
          talker.info('Received LiveActivity push-to-start token: ${event.token}');
        default:
          talker.info('Ignoring live activity event: $event');
      }
    });
    _subscriptions.add(s);
  }

  /// Setups the listeners for the printer data for all machines.
  void _setupPrinterDataListeners() {
    talker.info('Setting up printerData listeners');
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

        talker.info(
            'Added ${listenersToOpen.length} new printerData listeners and removed ${listenersToClose.length} printer listeners in the LiveActivityService');
      }),
      fireImmediately: true,
    );
  }

  /// Do a check if we need to refresh the live activities for all machines when the app is resumed.
  void _registerAppLifecycleHandler() {
    talker.info('Registering AppLifecycle handler');
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
    talker.info('Refreshing live activities');
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
      talker.info('Finished refreshing live activities');
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

      final etaSources = _settingsService
          .readList<ETADataSource>(AppSettingKeys.etaSources, elementDecoder: ETADataSource.fromJson)
          .toSet();

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

      // talker.info('Progress: $hasProgressChange, State: $hasStateChange, File: $hasFileChange, ETA: $hasEtaChange, Clear: $clearLiveActivity, Create: $createLiveActivity, Delta: $deltaWindow');
      if (!hasDataReady ||
          !createLiveActivity &&
              !clearLiveActivity &&
              !hasProgressChange &&
              !hasStateChange &&
              !hasFileChange &&
              !hasEtaChange) return;
      // talker.info('Passed the refresh check for machine $machineUUID (Progress: $hasProgressChange, State: $hasStateChange, File: $hasFileChange, ETA: $hasEtaChange, Clear: $clearLiveActivity, Create: $createLiveActivity)');
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
        talker.warning('Could not acquire lock for machine $machineUUID. Skipping activity refresh.');
        return false;
      }

      // Acquire lock
      lock = Completer();
      _refreshActivityLocks[machineUUID] = lock;

      // Get machine data
      final machine = await ref.read(machineProvider(machineUUID).future);
      if (machine == null) return false;

      // talker.info('Refreshing live activity for machine ${machine.logNameExtended}');
      final themePack = ref.read(themeServiceProvider).activeTheme.themePack;
      final etaSources = _settingsService
          .readList<ETADataSource>(AppSettingKeys.etaSources, elementDecoder: ETADataSource.fromJson)
          .toSet();
      final attributes = LiveActivityAttributesMessage(
        machineUUID: machineUUID,
        machineName: machine.name,
        colorLight: themePack.lightTheme.colorScheme.primary.toARGB32(),
        colorDark: (themePack.darkTheme ?? themePack.lightTheme).colorScheme.primary.toARGB32(),
        etaLabel: tr('pages.dashboard.general.print_card.eta'),
        remainingLabel: tr('pages.dashboard.general.print_card.remaining'),
        stateLabels: {for (var state in PrintState.values) state.name: state.displayName},
      );
      final content = LiveActivityContentMessage(
        progress: printer.printProgress,
        eta: printer.calcEta(etaSources)?.secondsSinceEpoch ?? -1,
        printState: printer.print.state.name,
        file: printer.currentFile?.name ?? tr('general.unknown'),
      );

      var isPrinting = {PrintState.printing, PrintState.paused}.contains(printer.print.state);

      if (isPrinting) {
        // Do not block the activity for too long on slow (remote) connections, the image shows up with the next update
        await _syncThumbnail(machineUUID, printer.currentFile).timeout(const Duration(seconds: 5), onTimeout: () {});
        await _updateOrCreateLiveActivity(attributes, content);
      } else {
        // Only remove the activity if the app is not in the resumed state -> This is to prevent the activity from being removed when the app is in the background and usefull for the user to see
        if (ref.read(appLifecycleProvider) != AppLifecycleState.resumed) {
          talker.info('App is not in resumed state. Skipping activity removal for machine $machineUUID');
          return false;
        }
        final activity = _machineActivityMapping.remove(machineUUID);
        // Remove the activity if the printer is not printing or paused
        if (activity != null && ref.read(remoteConfigBoolProvider('clear_live_activity_on_done'))) {
          _liveActivityAPI.end(machineUUID, null, true).ignore();
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

  /// Stores the thumbnail of the printed file for the widget. Only downloaded once per file.
  Future<void> _syncThumbnail(String machineUUID, GCodeFile? file) async {
    if (file == null || _thumbnailFiles[machineUUID] == file.name) return;
    // Thumbnails are sorted by size, the smallest one that is still big enough for the activity is sufficient
    final thumbnail =
        file.thumbnails.firstWhereOrNull((e) => e.width >= 100 && e.height >= 100) ?? file.thumbnails.lastOrNull;
    if (thumbnail == null) return;

    final dioSubscription = ref.keepAliveExternally(dioClientProvider(machineUUID));
    try {
      final dio = dioSubscription.read();
      final baseUri = Uri.parse(dio.options.baseUrl);
      final uri = baseUri.replace(pathSegments: [
        ...baseUri.pathSegments,
        'server',
        'files',
        ...file.parentPath.split('/'),
        ...thumbnail.relativePath.split('/'),
      ]);

      final response = await dio.getUri<List<int>>(uri, options: Options(responseType: ResponseType.bytes));
      final bytes = response.data;
      if (bytes == null) return;

      await _liveActivityAPI.setThumbnail(machineUUID, file.name, Uint8List.fromList(bytes));
      _thumbnailFiles[machineUUID] = file.name;
      talker.info('Stored LiveActivity thumbnail ${thumbnail.width}x${thumbnail.height} for $machineUUID');
    } catch (e) {
      // Retried with the next refresh
      talker.warning('Could not store LiveActivity thumbnail for $machineUUID', e);
    } finally {
      dioSubscription.close();
    }
  }

  /// Updates or creates a live activity for a machine.
  /// Note that this does not require a lock as it is part of the refreshLiveActivityForMachine method which already has a lock.
  Future<String?> _updateOrCreateLiveActivity(
    LiveActivityAttributesMessage attributes,
    LiveActivityContentMessage content,
  ) async {
    final machineUUID = attributes.machineUUID;
    // Get platform info about the current active activities
    final running = await _liveActivityAPI
        .getActivities()
        .then((value) => value.where((e) => _isRunning(e.state)).toList());
    if (running.length >= 5 && running.none((e) => e.machineUUID == machineUUID)) {
      talker.warning('Cannot create new LiveActivity for $machineUUID. Too many activities are already active.');
      return null;
    }

    try {
      final activityId = await _liveActivityAPI.createOrUpdate(attributes, content);
      // Do not override the entry if it is the same activity, the push token might already be set
      if (_machineActivityMapping[machineUUID]?.activityId != activityId) {
        _machineActivityMapping[machineUUID] = _ActivityEntry(activityId);
        talker.info('Created new LiveActivity for $machineUUID with id: $activityId');
      } else {
        talker.info('Updated LiveActivity for $machineUUID');
      }
      return activityId;
    } on PlatformException catch (e) {
      // E.g. the OS does not allow starting an activity while the app is in the background
      talker.warning('Failed to create or update LiveActivity for $machineUUID: ${e.message} (${e.details})');
      return null;
    }
  }

  void dispose() {
    talker.error('The LiveActivityService was disposed! THIS SHOULD NEVER HAPPEN! CHECK THE DISPOSING!!!');
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
