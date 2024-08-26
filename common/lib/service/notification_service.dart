/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:awesome_notifications_fcm/awesome_notifications_fcm.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/model_event.dart';
import 'package:common/service/live_activity_service.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/logging_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'live_activity_service_v2.dart';

part 'notification_service.g.dart';

@Riverpod(keepAlive: true)
AwesomeNotifications awesomeNotification(AwesomeNotificationRef ref) => AwesomeNotifications();

@riverpod
AwesomeNotificationsFcm awesomeNotificationFcm(AwesomeNotificationFcmRef ref) => AwesomeNotificationsFcm();

@riverpod
NotificationService notificationService(NotificationServiceRef ref) {
  ref.keepAlive();
  var notificationService = NotificationService(ref);
  ref.onDispose(notificationService.dispose);
  return notificationService;
}

@riverpod
Future<String> fcmToken(FcmTokenRef ref) async {
  // Need to use read on the notificationService to prevent a circular dependency, this is fine because the service is kept alive anyway.
  var notificationService = ref.read(notificationServiceProvider);
  await notificationService.initialized;
  return notificationService.requestFirebaseToken();
}

class NotificationService {
  static const String _notificationTappedPortName = 'onNoti';
  static const String _fcmTokenUpdatedPortName = 'tknUpdat';
  static const String _marketingTopic = 'marketing';

  NotificationService(this._ref)
      : _machineService = _ref.watch(machineServiceProvider),
        _settingsService = _ref.watch(settingServiceProvider),
        _notifyAPI = _ref.watch(awesomeNotificationProvider),
        _liveActivityService = _ref.watch(liveActivityServiceProvider),
        _liveActivityServicev2 = _ref.watch(v2LiveActivityProvider),
        _notifyFCM = _ref.watch(awesomeNotificationFcmProvider);

  final AutoDisposeRef _ref;
  final MachineService _machineService;
  final SettingService _settingsService;
  final AwesomeNotifications _notifyAPI;
  final AwesomeNotificationsFcm _notifyFCM;
  final LiveActivityService _liveActivityService;
  final LiveActivityServiceV2 _liveActivityServicev2;

  final ReceivePort _notificationTapPort = ReceivePort();
  final ReceivePort _fcmTokenUpdatePort = ReceivePort();

  StreamSubscription<ModelEvent<Machine>>? _machineRepoUpdateListener;
  final Map<String, ProviderSubscription> _fcmUpdateListeners = {};

  final Completer<bool> _initialized = Completer<bool>();

  Future<bool> get initialized => _initialized.future;

  Future<void> initialize(List<String> licenseKeys) async {
    try {
      await _initialRequestPermission();
      _initializedPorts();

      var allMachines = await _ref.read(allMachinesProvider.future);
      var hiddenMachines = await _ref.read(hiddenMachinesProvider.future);

      await _initializeNotifyApi(allMachines);
      // ToDo: Add listener to token update to clear fcm.cfg!
      // ToDo: Implement local notification handling again!
      _initializeLocalMessageHandling(allMachines);
      _initializeRemoteMessaging(licenseKeys, allMachines, hiddenMachines).ignore();

      // await _liveActivityService.initialize();
      await _liveActivityServicev2.initialize();

      _initializeMachineRepoListener();

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

  Future<bool> requestNotificationPermission() async {
    await _settingsService.writeBool(UtilityKeys.requestedNotifyPermission, true);
    return _notifyAPI.requestPermissionToSendNotifications();
  }

  Future<bool> hasNotificationPermission() {
    var notificationAllowed = _notifyAPI.isNotificationAllowed();
    return notificationAllowed;
  }

  void onMachineAdded(Machine machine) {
    // Channels wont work since the group needs to be created first!
    // List<NotificationChannel> channelsOfmachines = _channelsForMachine(machine);
    // for (var channels in channelsOfmachines) {
    //   _notifyAPI.setChannel(channels);
    // }
    _setupMachineFcmUpdater(machine);
    _registerLocalMessageHandlingForMachine(machine);
    logger.i('Added stream-listener for ${machine.logName}');
  }

  void onMachineRemoved(String uuid) {
    _notifyAPI.removeChannel('$uuid-statusUpdates');
    _notifyAPI.removeChannel('$uuid-progressUpdates');
    _fcmUpdateListeners.remove(uuid)?.close();
    logger.i('Removed notifications channels and stream-listener for UUID=$uuid');
  }

  Future<bool> isFirebaseAvailable() async => _notifyFCM.isFirebaseAvailable.onError((e, _) {
        logger.w('Firebase is not available for FCM...', e);
        return false;
      });

  Future<String> requestFirebaseToken() async => _notifyFCM.requestFirebaseAppToken();

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

  void _initializeLocalMessageHandling(List<Machine> allMachines) async {
    await _initializeNotificationListeners();
    // ToDo Decide if local messages should be handled again!
    // if (!Platform.isIOS) return;

    // for (Machine setting in allMachines) {
    // _registerLocalMessageHandlingForMachine(setting);
    // }
  }

  void _registerLocalMessageHandlingForMachine(Machine machine) {
    // ToDo Decide if local messages should be handled again!
    // if (!Platform.isIOS) return;
    // _printerStreamMap[machine.uuid] = ref.listen(printerProvider(machine.uuid), (previous, AsyncValue<Printer> next) {
    //   next.whenData((value) => _processPrinterUpdate(machine, value));
    // });
    //TODO: _printerStreamMap must be added again and also in the onMachineRemoved!
  }

  Future<void> _initializeNotificationListeners() {
    logger.i('Initializing notification listeners');
    return _notifyAPI.setListeners(onActionReceivedMethod: _onActionReceivedMethod);
  }

  void _initializeMachineRepoListener() {
    logger.i('Initializing machineRepoListener');
    _machineRepoUpdateListener = _machineService.machineModelEvents.listen((event) {
      logger.i('Received machineModelEvents: ${event.runtimeType}(${event.key}:${event.data}');

      switch (event) {
        case ModelEventInsert<Machine> event:
          onMachineAdded(event.data);
          break;
        case ModelEventUpdate<Machine> event:
          break;
        case ModelEventDelete<Machine> event:
          onMachineRemoved(event.key);
          break;
      }
    });
  }

  Future<void> _initializeNotifyApi(List<Machine> machines) async {
    // Always have a basic channel!
    List<NotificationChannelGroup> groups = [
      NotificationChannelGroup(channelGroupKey: 'mobileraker_default_grp', channelGroupName: 'Mobileraker')
    ];
    List<NotificationChannel> channels = [
      NotificationChannel(
        channelKey: 'basic_channel',
        channelName: 'News & Updates',
        channelDescription: 'Stay updated with Mobileraker! Get the latest news and important info here.',
        channelGroupKey: 'mobileraker_default_grp',
      ),
      NotificationChannel(
        channelKey: 'marketing_channel',
        channelName: 'Promotions',
        channelDescription: 'Be the first to know about special promotions and discounts!',
        channelGroupKey: 'mobileraker_default_grp',
      )
    ];
    // Each machine should have its own channel and grp!
    for (Machine setting in machines) {
      groups.add(_channelGroupForMachine(setting));
      channels.addAll(_channelsForMachine(setting));
    }

    await _notifyAPI.initialize(
        // set the icon to null if you want to use the default app icon
        null,
        channels,
        channelGroups: groups);
    logger.i('Successfully initialized AwesomeNotifications and created channels and groups!');
  }

  Future<void> _initializeRemoteMessaging(
      List<String> licenseKeys, List<Machine> allMachines, List<Machine> hiddenMachines) async {
    logger.i('Initializing remote messaging');
    hiddenMachines.forEach(_wipeFCMOnPrinterOnceConnected);
    if (await isFirebaseAvailable()) {
      await _notifyFCM.initialize(
          onFcmTokenHandle: _awesomeNotificationFCMTokenHandler,
          onFcmSilentDataHandle: _awesomeNotificationFCMBackgroundHandler,
          licenseKeys: licenseKeys);
      allMachines.forEach(_setupMachineFcmUpdater);
      _setupFcmTopicNotifications();
    }
  }

  void _initializedPorts() {
    // This might create a Race Condition, However in my case doing it like that is fine
    // Since AwesomeFCM  creates an Isolate only once the notification is tapped!
    IsolateNameServer.removePortNameMapping(_notificationTappedPortName);
    IsolateNameServer.registerPortWithName(_notificationTapPort.sendPort, _notificationTappedPortName);
    IsolateNameServer.removePortNameMapping(_fcmTokenUpdatedPortName);
    IsolateNameServer.registerPortWithName(_fcmTokenUpdatePort.sendPort, _fcmTokenUpdatedPortName);

    // No need to close this sub, since I close the port!
    _notificationTapPort.listen(_onNotificationTapPortMessage, onError: _onNotificationTapPortError);
    _fcmTokenUpdatePort.listen(_onFcmTokenUpdatePortMessage, onError: _onFcmTokenUpdatePortError);
    logger.i('Successfully initialized ports!');
  }

  @pragma('vm:entry-point')
  static Future<void> _onActionReceivedMethod(ReceivedAction receivedAction) async {
    SendPort? port = IsolateNameServer.lookupPortByName(_notificationTappedPortName);
    if (port != null) {
      port.send(receivedAction.toMap());
    } else {
      logger.e('Received an action from the onActionReceivedMethod Port but the port is null!');
    }
  }

  Future<void> _onNotificationTapPortMessage(dynamic data) async {
    if (data is! Map<String, dynamic>) {
      logger.w(
          'Received object from the onNotificationTap Port is not of type: Map<String, dynamic> it is type:${data.runtimeType}');
      return;
    }

    final receivedAction = ReceivedAction().fromMap(data);
    var payload = receivedAction.payload;
    logger.i('Received payload from notification port: $payload');

    if (payload?.containsKey('printerId') == true) {
      var machine = await _machineService.fetch(payload!['printerId']!);
      if (machine != null) {
        await _ref.read(selectedMachineServiceProvider).selectMachine(machine);
        logger.i(
            'Successfully switched to printer ${machine.logName} that was contained in the notification\'s ReceivedAction');
        return;
      }
    }
    logger.i('No action taken from the ReceivedAction');
  }

  Future<void> _onNotificationTapPortError(error) async {
    logger.e('Received an error from the onNotificationTap Port', e);
  }

  @pragma('vm:entry-point')
  static Future<void> _awesomeNotificationFCMTokenHandler(String firebaseToken) async {
    SendPort? port = IsolateNameServer.lookupPortByName(_fcmTokenUpdatedPortName);
    if (port != null) {
      port.send(firebaseToken);
    } else {
      logger.e('Received an action from the onActionReceivedMethod Port but the port is null!');
    }
  }

  Future<void> _onFcmTokenUpdatePortMessage(dynamic token) async {
    if (token is! String) {
      logger.w(
          'Received object from the onNotificationTap Port is not of type: ReceivedAction it is type:${token.runtimeType}');
      return;
    }
    logger.i('Token from FCM updated $token');
    _ref.invalidate(fcmTokenProvider);
  }

  Future<void> _onFcmTokenUpdatePortError(error) async {
    logger.e('Received an error from the onNotificationTap Port', e);
  }

  @pragma('vm:entry-point')
  static Future<void> _awesomeNotificationFCMBackgroundHandler(FcmSilentData message) async {}

  List<NotificationChannel> _channelsForMachine(Machine machine) {
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
      ),
      NotificationChannel(
        icon: 'resource://drawable/res_mobileraker_logo',
        channelKey: machine.printProgressBarChannelKey,
        channelName: 'Print Progressbar Updates - ${machine.name}',
        channelDescription: 'Permanent Progressbar, indicating the print progress.',
        channelGroupKey: machine.uuid,
        playSound: false,
        enableVibration: false,
        enableLights: false,
        importance: NotificationImportance.Low,
        defaultColor: Colors.white,
      )
    ];
  }

  NotificationChannelGroup _channelGroupForMachine(Machine machine) {
    return NotificationChannelGroup(channelGroupKey: machine.uuid, channelGroupName: 'Printer ${machine.name}');
  }

  void _setupFcmTopicNotifications() {
    logger.i('Setting up FCM topic notifications');
    _fcmUpdateListeners[_marketingTopic]?.close();

    _fcmUpdateListeners[_marketingTopic] =
        _ref.listen(boolSettingProvider(AppSettingKeys.receiveMarketingNotifications), (previous, next) {
      if (next == true) {
        logger.i('Subscribing to marketing topic');
        _notifyFCM.subscribeToTopic(_marketingTopic);
      } else {
        logger.i('Unsubscribing from marketing topic');
        _notifyFCM.unsubscribeToTopic(_marketingTopic);
      }
    }, fireImmediately: true);
  }

  void _setupMachineFcmUpdater(Machine machine) {
    logger.i('Setting up FCM updater for ${machine.logNameExtended}');

    var subscription =
        _ref.listen(klipperProvider(machine.uuid).selectAs((data) => data.klippyState), (previous, next) async {
      if (next.valueOrFullNull == KlipperState.ready) {
        var fcmToken = await _notifyFCM.requestFirebaseAppToken();
        try {
          logger.i('Updating FCM settings on ${machine.logNameExtended}');
          await _machineService.updateMachineFcmSettings(machine, fcmToken);
        } catch (e, s) {
          logger.w('Could not updateMachineFcmSettings on ${machine.logNameExtended}', e, s);
        }
      }
    });

    _fcmUpdateListeners.remove(machine.uuid)?.close();
    _fcmUpdateListeners[machine.uuid] = subscription;
  }

  Future<void> _wipeFCMOnPrinterOnceConnected(Machine machine) async {
    logger.i('Wiping FCM data on ${machine.logNameExtended}');
    var mProvider = machineProvider(machine.uuid);
    var keepAliveExternally = _ref.keepAliveExternally(mProvider);
    try {
      // Ensure a machine provider is available for JRPC, Klippy....
      // Kinda meh to put this here but I also dont care lol
      await _ref.read(mProvider.future);
      // Wait until connected
      await _ref.readWhere<KlipperInstance>(klipperProvider(machine.uuid), (c) => c.klippyState == KlipperState.ready);
      logger.i('Jrpc Client of ${machine.logNameExtended} is connected, WIPING FCM data on printer now!');
      await _machineService.removeFCMCapability(machine);
    } catch (e, s) {
      logger.w('Could not WIPE fcm data on ${machine.logNameExtended}', e, s);
    } finally {
      // Since I initited the provider before and all hidden machines dont have a machineProvider setup, also remove it again!
      keepAliveExternally.close();
      _ref.invalidate(mProvider);
    }
  }

  dispose() {
    logger.e('NEVER DISPOSE THIS SERVICE!');
    _notificationTapPort.close();
    _machineRepoUpdateListener?.cancel();

    _initialized.completeError(StateError('Disposed notification service before it was initialized!'));
  }
}
