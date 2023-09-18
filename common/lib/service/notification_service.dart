/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:io';
import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:awesome_notifications_fcm/awesome_notifications_fcm.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/machine/printer.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/hive/notification.dart';
import 'package:common/data/model/hive/progress_notification_mode.dart';
import 'package:common/data/repository/notifications_hive_repository.dart';
import 'package:common/data/repository/notifications_repository.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/theme_service.dart';
import 'package:common/util/extensions/date_time_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/extensions/uri_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/live_activity_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_service.g.dart';

@Riverpod(keepAlive: true)
AwesomeNotifications awesomeNotification(AwesomeNotificationRef ref) => AwesomeNotifications();

@riverpod
AwesomeNotificationsFcm awesomeNotificationFcm(AwesomeNotificationFcmRef ref) => AwesomeNotificationsFcm();

@Riverpod(keepAlive: true)
LiveActivities liveActivity(LiveActivityRef ref) {
  return LiveActivities();
}

@riverpod
NotificationService notificationService(NotificationServiceRef ref) {
  var notificationService = NotificationService(ref);
  ref.onDispose(notificationService.dispose);
  ref.keepAlive();
  return notificationService;
}

@riverpod
Future<String> fcmToken(FcmTokenRef ref) async {
  var notificationService = ref.watch(notificationServiceProvider);
  await notificationService.initialized;
  return notificationService.fetchCurrentFcmToken();
}

class NotificationService {
  static const String _portName = 'onNoti';

  NotificationService(this.ref)
      : _machineService = ref.watch(machineServiceProvider),
        _settingsService = ref.watch(settingServiceProvider),
        _notifyAPI = ref.watch(awesomeNotificationProvider),
        _liveActivityAPI = ref.watch(liveActivityProvider),
        _notificationsRepository = ref.watch(notificationRepositoryProvider),
        _notifyFCM = ref.watch(awesomeNotificationFcmProvider);

  final AutoDisposeRef ref;
  final MachineService _machineService;
  final SettingService _settingsService;
  final AwesomeNotifications _notifyAPI;
  final AwesomeNotificationsFcm _notifyFCM;
  final LiveActivities _liveActivityAPI;
  final NotificationsRepository _notificationsRepository;
  final Map<String, ProviderSubscription<AsyncValue<Printer>>> _printerStreamMap = {};
  final ReceivePort _notificationTapPort = ReceivePort();

  final Map<String, String> _machineLiveActivityIdMap = {};
  final Completer _liveActivityInitCompleter = Completer();
  Completer? _updateLiveActivityLock;

  StreamSubscription<BoxEvent>? _hiveStreamListener;
  final Completer<bool> _initialized = Completer<bool>();

  Future<bool> get initialized => _initialized.future;

  Future<void> initialize(List<String> licenseKeys) async {
    try {
      await _initialRequestPermission();
      if (Platform.isIOS) {
        _liveActivityInitCompleter.complete(_liveActivityAPI.init(appGroupId: "group.mobileraker.liveactivity"));
        _liveActivityAPI.activityUpdateStream.listen((event) {
          logger.i('LiveActivity update: $event');
        });
      }

      List<Machine> allMachines = await ref.read(allMachinesProvider.future);
      ref
          .read(hiddenMachinesProvider.future)
          .then((res) => Future.wait(res.map(_wipeFCMOnPrinterOnceConnected)))
          .ignore();

      await _initializeNotificationChannels(allMachines);

      // ToDo: Add listener to token update to clear fcm.cfg!
      // ToDo: Implement local notification handling again!
      for (Machine setting in allMachines) {
        _registerLocalMessageHandling(setting);
      }

      _hiveStreamListener = _setupHiveBoxListener();

      _initializedPortForTask();
      await _initializeNotificationListeners();
      _initializeRemoteMessaging(licenseKeys, allMachines).ignore();

      logger.i('Completed NotificationService init');
    } catch (e, s) {
      FirebaseCrashlytics.instance.recordError(
        e,
        s,
        reason: 'Error while setting up notificationService',
      );
      logger.w('Error encountered while trying to setup the Notification Service.', e, s);
    } finally {
      _initialized.complete(true);
    }
  }

  Future<bool> _initialRequestPermission() async {
    bool notificationAllowed = await hasNotificationPermission();
    logger.i('Notifications are permitted: $notificationAllowed');

    if (_settingsService.readBool(UtilityKeys.requestedNotifyPermission, true)) {
      return notificationAllowed;
    }
    if (!notificationAllowed) {
      return requestNotificationPermission();
    }
    return notificationAllowed;
  }

  Future<bool> requestNotificationPermission() async {
    await _settingsService.writeBool(UtilityKeys.requestedNotifyPermission, true);
    return _notifyAPI.requestPermissionToSendNotifications();
  }

  Future<bool> hasNotificationPermission() {
    var notificationAllowed = _notifyAPI.isNotificationAllowed();
    return notificationAllowed;
  }

  void _registerLocalMessageHandling(Machine setting) {
    // ToDo: Implement local notification handling again!
    // return;
    if (!Platform.isIOS) return;
    _printerStreamMap[setting.uuid] = ref.listen(printerProvider(setting.uuid), (previous, AsyncValue<Printer> next) {
      next.whenData((value) => _processPrinterUpdate(setting, value));
    });
  }

  Future<void> _initializeNotificationListeners() {
    return _notifyAPI.setListeners(onActionReceivedMethod: _onActionReceivedMethod);
  }

  StreamSubscription<BoxEvent> _setupHiveBoxListener() {
    return _machineService.machineEventStream.listen((event) {
      logger.d("Received Box-Event<machine>: event(${event.key}:${event.value} del=${event.deleted}");
      if (event.deleted) {
        onMachineRemoved(event.key);
      } else if (!_printerStreamMap.containsKey(event.key)) {
        onMachineAdded(event.value);
      }
    });
  }

  Future<void> _initializeNotificationChannels(List<Machine> machines) async {
    // Always have a basic channel!
    List<NotificationChannelGroup> groups = [
      NotificationChannelGroup(channelGroupKey: 'mobileraker_default_grp', channelGroupName: 'Mobileraker')
    ];
    List<NotificationChannel> channels = [
      NotificationChannel(
        channelKey: 'basic_channel',
        channelName: 'General Notifications',
        channelDescription: 'Notifications regarding updates and infos about Mobileraker!',
        channelGroupKey: 'mobileraker_default_grp',
      )
    ];
    // Each machine should have its own channel and grp!
    for (Machine setting in machines) {
      groups.add(_channelGroupOfmachines(setting));
      channels.addAll(_channelsOfmachines(setting));
    }

    await _notifyAPI.initialize(
        // set the icon to null if you want to use the default app icon
        null,
        channels,
        channelGroups: groups);
    logger.i('Setup notification channels');
  }

  Future<void> _initializeRemoteMessaging(List<String> licenseKeys, List<Machine> allMachines) async {
    if (await isFirebaseAvailable()) {
      await _notifyFCM.initialize(
          onFcmTokenHandle: _awesomeNotificationFCMTokenHandler,
          onFcmSilentDataHandle: _awesomeNotificationFCMBackgroundHandler,
          licenseKeys: licenseKeys);
      for (var e in allMachines) {
        _setupFCMOnPrinterOnceConnected(e).ignore();
      }
    }
  }

  Future<void> updatePrintStateOnce() async {
    List<Machine> allMachines = await _machineService.fetchAll();
    for (Machine machine in allMachines) {
      ref.read(printerProvider(machine.uuid)).whenData((value) {
        _processPrinterUpdate(machine, value);
      });
    }
  }

  void _initializedPortForTask() {
    // This might create a Race Condition, However in my case doing it like that is fine
    // Since AwesomeFCM  creates an Isolate only once the notification is tapped!
    IsolateNameServer.removePortNameMapping(_portName);
    IsolateNameServer.registerPortWithName(_notificationTapPort.sendPort, _portName);

    // No need to close this sub, since I close the port!
    _notificationTapPort.listen(_onNotificationTapPortMessage, onError: _onNotificationTapPortError);
    logger.i('Setup ReceiverPort!');
  }

  // updatePrintStateOnce() {
  //   Iterable<machine> allMachines = _machineService.fetchAll();
  //   logger.i('Updating PrintState once for BG task?');
  //   for (machine setting in allMachines) {
  //     WebSocketWrapper websocket = setting.websocket;
  //     bool connection = websocket.ensureConnection();
  //
  //     logger.i(
  //         'WS-Connection for ${setting.name} was ${connection ? 'OPEN' : 'CLOSED -  Trying to open again'}');
  //   }
  // }

  double normalizeProgress(ProgressNotificationMode mode, double prog) {
    double m;
    switch (mode) {
      case ProgressNotificationMode.FIVE:
        m = 0.05;
        break;
      case ProgressNotificationMode.TEN:
        m = 0.10;
        break;
      case ProgressNotificationMode.TWENTY:
        m = 0.20;
        break;
      case ProgressNotificationMode.TWENTY_FIVE:
        m = 0.25;
        break;
      case ProgressNotificationMode.FIFTY:
        m = 0.50;
        break;
      default:
        return prog;
    }
    return prog - prog % m;
  }

  Future<String> fetchCurrentFcmToken() async {
    return _notifyFCM.requestFirebaseAppToken();
  }

  void onMachineAdded(Machine setting) {
    List<NotificationChannel> channelsOfmachines = _channelsOfmachines(setting);
    for (var channels in channelsOfmachines) {
      _notifyAPI.setChannel(channels);
    }
    _setupFCMOnPrinterOnceConnected(setting);
    _registerLocalMessageHandling(setting);
  }

  void onMachineRemoved(String uuid) {
    _notifyAPI.removeChannel('$uuid-statusUpdates');
    _notifyAPI.removeChannel('$uuid-progressUpdates');
    _printerStreamMap.remove(uuid)?.close();
    logger.i("Removed notifications channels and stream-listener for UUID=$uuid");
  }

  @pragma("vm:entry-point")
  static Future<void> _onActionReceivedMethod(ReceivedAction receivedAction) async {
    SendPort? uiSendPort = IsolateNameServer.lookupPortByName(_portName);
    if (uiSendPort != null) {
      logger.e('Background action running on parallel isolate without valid context. Redirecting execution');
      uiSendPort.send(receivedAction);
    } else {
      logger.e('??? Port is null wtf??');
    }
  }

  Future<void> _onNotificationTapPortMessage(dynamic data) async {
    if (data is! ReceivedAction) {
      logger.w(
          'Received object from the onNotificationTap Port is not of type: ReceivedAction it is type:${data.runtimeType}');
      return;
    }
    var payload = data.payload;
    logger.i('Received payload: $payload');

    if (payload?.containsKey('printerId') == true) {
      var machine = await _machineService.fetch(payload!['printerId']!);
      if (machine != null) {
        await ref.read(selectedMachineServiceProvider).selectMachine(machine);
        logger.i(
            'Successfully switched to printer ${machine.debugStr} that was contained in the notification\'s ReceivedAction');
        return;
      }
    }
    logger.i('No action taken from the ReceivedAction');

    // Your code goes here
    // ref
    //     .read(selectedMachineProvider)
    //     .whenData((value) => ref.read(jrpcClientProvider(value!.uuid)));
  }

  Future<void> _onNotificationTapPortError(error) async {
    logger.e('Received an error from the onNotificationTap Port', e);
  }

  @pragma("vm:entry-point")
  static Future<void> _awesomeNotificationFCMTokenHandler(String firebaseToken) async {
    logger.i('Token from FCM $firebaseToken');

    // ToDo: Add listener to token update to clear fcm.cfg!
  }

  @pragma("vm:entry-point")
  static Future<void> _awesomeNotificationFCMBackgroundHandler(FcmSilentData message) async {
    // Todo: Do I even need background stuff ?
    // logger.i('Receieved a notif Message');
    // print('I-AM-COOL');
    // debugPrint('I-AM-COOL-DEBUG');

    // DartPluginRegistrant.ensureInitialized();
    // logger
    //     .wtf("Handling a background message: ${message.data} (${message.createdLifeCycle?.name})");
    //
    //
    // if (Platform.isAndroid) {
    //   // Only for Android a isolate is spawned!
    //   await setupBoxes();
    // }
    //
    // ProviderContainer container = ProviderContainer();
    // NotificationService notificationService =
    //     container.read(notificationServiceProvider);
    //
    // Map<String, String?>? data = message.data;
    // if (data != null && message.createdLifeCycle != NotificationLifeCycle.Foreground) {
    //   PrintState? state;
    //   if (data.containsKey('printState')) {
    //     state = EnumToString.fromString(
    //             PrintState.values, data['printState'] ?? '') ??
    //         PrintState.error;
    //   }
    //   String? printerIdentifier;
    //   if (data.containsKey('printerIdentifier')) {
    //     printerIdentifier = data['printerIdentifier'];
    //   }
    //   double? progress;
    //   if (data.containsKey('progress')) {
    //     var content = data['progress'];
    //     if (content != null) progress = double.tryParse(content);
    //   }
    //
    //   double? printingDuration;
    //   if (data.containsKey('printingDuration')) {
    //     var content = data["printingDuration"];
    //     if (content != null) printingDuration = double.tryParse(content);
    //   }
    //   String? file;
    //   if (data.containsKey('filename')) file = data['filename'];
    //
    //   if (state != null && printerIdentifier != null) {
    //     Machine? machine = await notificationService._machineService
    //         .machineFromFcmIdentifier(printerIdentifier);
    //     if (machine != null) {
    //       var printState = await notificationService
    //           ._updatePrintStatusNotification(machine, state, file);
    //       if (printState == PrintState.printing &&
    //           progress != null &&
    //           printingDuration != null) {
    //         await notificationService._updatePrintProgressNotification(
    //             machine, progress, printingDuration);
    //       }
    //       await machine.save();
    //     }
    //   }
    // } else {
    //   logger.e('Received data was empty!');
    // }
    // await Future.delayed(Duration(milliseconds: 200));
    // container.dispose();
  }

  List<NotificationChannel> _channelsOfmachines(Machine machine) {
    return [
      NotificationChannel(
          icon: 'resource://drawable/res_mobileraker_logo',
          channelKey: machine.statusUpdatedChannelKey,
          channelName: 'Print Status Updates - ${machine.name}',
          channelDescription: 'Notifications regarding the print status.',
          channelGroupKey: machine.uuid,
          // importance: NotificationImportance.Default,
          defaultColor: Colors.white,
          playSound: true,
          enableVibration: true),
      NotificationChannel(
          icon: 'resource://drawable/res_mobileraker_logo',
          channelKey: machine.m117ChannelKey,
          channelName: 'User M117 Notifications - ${machine.name}',
          channelDescription: 'Notifications issued by M117 with prefix "\$MR\$:".',
          channelGroupKey: machine.uuid,
          // importance: NotificationImportance.Max,
          defaultColor: Colors.white,
          playSound: true,
          enableVibration: true),
      NotificationChannel(
        icon: 'resource://drawable/res_mobileraker_logo',
        channelKey: machine.printProgressChannelKey,
        channelName: 'Print Progress Updates - ${machine.name}',
        channelDescription: 'Notifications regarding the print progress.',
        channelGroupKey: machine.uuid,
        playSound: false,
        enableVibration: false,
        enableLights: false,
        importance: NotificationImportance.Low,
        defaultColor: Colors.white,
      )
    ];
  }

  NotificationChannelGroup _channelGroupOfmachines(Machine machine) {
    return NotificationChannelGroup(channelGroupKey: machine.uuid, channelGroupName: 'Printer ${machine.name}');
  }

  Future<void> _setupFCMOnPrinterOnceConnected(Machine machine) async {
    String fcmToken = await fetchCurrentFcmToken(); // TODO: Extract to seperate provider
    logger.i('${machine.name}(${machine.wsUri.obfuscate()})  Device\'s FCM token: $fcmToken');
    try {
      // Wait until connected
      await ref.readWhere<KlipperInstance>(klipperProvider(machine.uuid), (c) => c.klippyState == KlipperState.ready);
      logger.i(
          'Jrpc Client of ${machine.name}(${machine.wsUri.obfuscate()}) is connected, can Setup FCM on printer now!');
      await _machineService.updateMachineFcmSettings(machine, fcmToken);
    } catch (e, s) {
      logger.w('Could not setupFCM on ${machine.name}(${machine.wsUri.obfuscate()})', e, s);
    }
  }

  Future<void> _wipeFCMOnPrinterOnceConnected(Machine machine) async {
    try {
      // Ensure a machine provider is available for JRPC, Klippy....
      // Kinda meh to put this here but I also dont care lol
      var mProvider = machineProvider(machine.uuid);
      await ref.read(mProvider.future);
      // Wait until connected
      await ref.readWhere<KlipperInstance>(klipperProvider(machine.uuid), (c) => c.klippyState == KlipperState.ready);
      logger.i('Jrpc Client of ${machine.name}(${machine.wsUri}) is connected, WIPING FCM data on printer now!');
      await _machineService.removeFCMCapability(machine);
      // Since I initited the provider before and all hidden machines dont have a machineProvider setup, also remove it again!
      ref.invalidate(mProvider);
    } catch (e, s) {
      logger.w('Could not WIPE fcm data on ${machine.name}(${machine.wsUri.obfuscate()})', e, s);
    }
  }

  Future<void> _processPrinterUpdate(Machine machine, Printer printer) async {
    // logger.wtf('_processPrinterUpdate.${machine.uuid}');
    if (!_initialized.isCompleted) return;
    if (!_liveActivityInitCompleter.isCompleted) return;
    if (!await _liveActivityAPI.areActivitiesEnabled()) return;
    Notification? notification = await _notificationsRepository.getByMachineUuid(machine.uuid);
    notification ??= Notification(machineUuid: machine.uuid);

    await _updateLiveActivity(machine, printer, notification);

    await _notificationsRepository.save(notification);

    // var state = await _updatePrintStatusNotification(machine, printer.print.state, printer.print.filename, false);

    // if (state == PrintState.printing && !Platform.isIOS) {
    //   await _updatePrintProgressNotification(machine, printer.printProgress, printer.print.printDuration, false);
    // }
    // await machine.save();
  }

  Future<void> _updateLiveActivity(Machine machine, Printer printer, Notification notification) async {
    // Pseudo lock to prevent to many updates at once
    if (_updateLiveActivityLock?.let((it) => !it.isCompleted) ?? false) {
      await _updateLiveActivityLock!.future;
      return _updateLiveActivity(machine, printer, notification);
    }

    _updateLiveActivityLock = Completer();
    try {
      var printState = printer.print.state;
      // logger.wtf('PrintProgress ${printer.printProgress} - ${notification.progress}');
      // logger.wtf('PrintState ${printState} - ${notification.printState}');
      final hasProgressChange = {PrintState.printing, PrintState.paused}.contains(printState) &&
          notification.progress != null &&
          ((notification.progress! - printer.printProgress) * 100).abs() > 2;
      final hasStateChange = notification.printState != printState;
      if (!hasProgressChange && !hasStateChange) return;
      logger.i('LiveActivity Passed state and progress check. $printState, ${printer.printProgress}');

      var themePack = ref.read(themeServiceProvider).activeTheme.themePack;
      Map<String, dynamic> data = {
        'progress': printer.printProgress,
        'state': printer.print.state.name,
        'file': printer.currentFile?.name ?? 'Unknown',
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
      };

      if (hasProgressChange) {
        logger.i('Detected progress change for ${machine.name} - ${printer.printProgress}');

        await _updateOrCreateLiveActivity(data, machine);
      } else if (hasStateChange) {
        logger.i('Detected state change for ${machine.name} - $printState');
        switch (printState) {
          case PrintState.paused:
          case PrintState.printing:
            //No need to create a activity, it should already be present. Worst case, it will be created by the progress checl
            await _updateOrCreateLiveActivity(data, machine);
            break;
          default:
            _endLiveActivity(machine.uuid);
        }
      }

      notification
        ..progress = printer.printProgress
        ..printState = printState;
    } finally {
      _updateLiveActivityLock!.complete();
    }
  }

  Future<String?> _updateOrCreateLiveActivity(Map<String, dynamic> data, Machine machine) async {
    if (_machineLiveActivityIdMap.containsKey(machine.uuid)) {
      var activityId = _machineLiveActivityIdMap[machine.uuid]!;
      LiveActivityState activityState = await _liveActivityAPI.getActivityState(activityId);
      //ToDo Unknown state of liveActivity might also be checked...
      logger.i('LiveActivityState for ${machine.name} is $activityState');
      if (activityState == LiveActivityState.active || activityState == LiveActivityState.stale) {
        activityId;
        await _liveActivityAPI.updateActivity(activityId, data);
        logger.i('Updating LiveActivity for ${machine.name} with id: $activityId}');
        return activityId;
      }
    }
    var allActivities = await _liveActivityAPI.getAllActivitiesIds();
    allActivities.where((element) => !_machineLiveActivityIdMap.containsValue(element)).forEach((element) {
      logger.i('Ending LiveActivity with id: $element, since it can not be addressed anymore!');
      _liveActivityAPI.endActivity(element);
    });
    var activityId = await _liveActivityAPI.createActivity(data);
    if (activityId != null) {
      _machineLiveActivityIdMap[machine.uuid] = activityId;
    }
    logger.i('Created new LiveActivity for ${machine.name} with id: $activityId');
    return activityId;
  }

  _endLiveActivity(String machineUuid) {
    _machineLiveActivityIdMap[machineUuid]?.let(_liveActivityAPI.endActivity);
    _machineLiveActivityIdMap.remove(machineUuid);
  }

  Future<PrintState> _updatePrintStatusNotification(Machine machine, PrintState updatedState, String? updatedFile,
      [bool createNotification = true]) async {
    PrintState? oldState = machine.lastPrintState;

    var allowed =
        _settingsService.read(AppSettingKeys.statesTriggeringNotification, 'standby,printing,paused,complete,error');

    if (updatedState == oldState) return updatedState;
    machine.lastPrintState = updatedState;
    logger.i("Transition update $oldState -> $updatedState");
    if (oldState == null && updatedState != PrintState.printing) {
      return updatedState;
    }

    if (
        // !allowed.contains(oldState?.name ?? PrintState.error.name) &&
        !allowed.contains(updatedState.name)) {
      logger.i('Skipping notifications,  "$oldState" nor "$updatedState" contained in allowedStates:"$allowed"');
      return updatedState;
    }

    String? body;
    Color? color;
    String file = updatedFile ?? 'Unknown';
    switch (updatedState) {
      case PrintState.standby:
        await _removePrintProgressNotification(machine);
        break;
      case PrintState.printing:
        body = 'Started to print file: "$file"';
        machine.lastPrintProgress = null;
        break;
      case PrintState.cancelled:
        body = 'Cancelled printing of file: "$file"';
        break;
      case PrintState.paused:
        body = 'Paused printing file: "$file"';
        break;
      case PrintState.complete:
        body = 'Finished printing: "$file"';
        await _removePrintProgressNotification(machine);
        break;
      case PrintState.error:
        if (oldState == PrintState.printing) {
          body = 'Error while printing file: "$file"';
          color = Colors.red;
        }
        await _removePrintProgressNotification(machine);
        break;
    }
    if (updatedState != PrintState.standby && createNotification) {
      NotificationContent notificationContent = NotificationContent(
        id: Random().nextInt(20000000),
        channelKey: machine.statusUpdatedChannelKey,
        title: 'Print state of ${machine.name} changed!',
        body: body,
        color: color,
        notificationLayout: NotificationLayout.BigText,
      );

      await _notifyAPI.createNotification(content: notificationContent);
    }

    return updatedState;
  }

  Future<void> _removePrintProgressNotification(Machine machine) =>
      _notifyAPI.cancelNotificationsByChannelKey(machine.printProgressChannelKey);

  Future<void> _updatePrintProgressNotification(Machine machine, double progress, double printDuration,
      [bool normalize = true]) async {
    if (progress >= 100) return;

    int readInt = _settingsService.readInt(AppSettingKeys.progressNotificationMode, -1);

    ProgressNotificationMode progMode =
        readInt >= 0 ? ProgressNotificationMode.values[readInt] : ProgressNotificationMode.TWENTY_FIVE;

    if (progMode == ProgressNotificationMode.DISABLED) return;

    double normalizedProgress = normalize ? normalizeProgress(progMode, progress) : progress;

    if (machine.lastPrintProgress == normalizedProgress) return;
    machine.lastPrintProgress = normalizedProgress;
    DateTime? dt;
    if (printDuration > 0 && progress > 0) {
      double est = printDuration / progress - printDuration;
      dt = DateTime.now().add(Duration(seconds: est.round()));
    }
    String eta = (dt != null) ? 'ETA: ${DateFormat.Hm().format(dt)}' : '';

    int index = await _machineService.indexOfMachine(machine);
    if (index < 0) return;

    var progressPerc = (normalizedProgress * 100).floor();
    await _notifyAPI.createNotification(
        content: NotificationContent(
            id: index * 3 + 3,
            channelKey: machine.printProgressChannelKey,
            title: 'Print progress of ${machine.name}',
            body: '$eta $progressPerc%',
            notificationLayout: NotificationLayout.ProgressBar,
            locked: true,
            progress: progressPerc));
  }

  Future<bool> isFirebaseAvailable() async {
    try {
      return await _notifyFCM.isFirebaseAvailable;
    } on PlatformException catch (e) {
      logger.w('Firebase is not available for FCM...', e);
      return false;
    }
  }

  dispose() {
    logger.e('NEVER DISPOSE THIS SERVICE!');
    _notificationTapPort.close();
    _hiveStreamListener?.cancel();
    for (var element in _printerStreamMap.values) {
      element.close();
    }
    _initialized.completeError(StateError('Disposed notification service before it was initialized!'));
  }
}
