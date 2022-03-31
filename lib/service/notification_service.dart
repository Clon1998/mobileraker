import 'dart:async';
import 'dart:io';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:mobileraker/app/app_setup.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/datasource/websocket_wrapper.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/dto/machine/print_stats.dart';
import 'package:mobileraker/dto/machine/printer.dart';
import 'package:mobileraker/firebase_options.dart';
import 'package:mobileraker/service/printer_service.dart';
import 'package:mobileraker/ui/theme_setup.dart';
import 'package:path_provider_android/path_provider_android.dart';
import 'package:path_provider_ios/path_provider_ios.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';
import 'package:shared_preferences_ios/shared_preferences_ios.dart';

import 'machine_service.dart';

class NotificationService {
  final _logger = getLogger('NotificationService');
  final _machineService = locator<MachineService>();
  final _notifyAPI = AwesomeNotifications();
  Map<String, StreamSubscription<Printer>> _printerStreamMap = {};
  StreamSubscription<ReceivedAction>? _actionStreamListener;
  StreamSubscription<BoxEvent>? _hiveStreamListener;

  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    // If you're going to use other Firebase services in the background, such as Firestore,
    // make sure you call `initializeApp` before using other Firebase services.

    // ToDo: on Flutter 2.11 swap this temp fix https://github.com/flutter/flutter/issues/98473#issuecomment-1060952450
    if (Platform.isAndroid) {
      PathProviderAndroid.registerWith();
      SharedPreferencesAndroid.registerWith();
    }
    if (Platform.isIOS) {
      PathProviderIOS.registerWith();
      SharedPreferencesIOS.registerWith();
    }
    await setupBoxes();
    setupLocator();
    await locator.allReady();
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    // await EasyLocalization.ensureInitialized();
    NotificationService notificationService = locator<NotificationService>();
    notificationService._logger.d(
        "Handling a background message: ${message.messageId} with ${message.data}");
    Map<String, dynamic> data = message.data;
    PrintState? state;
    if (data.containsKey('printState'))
      state = EnumToString.fromString(PrintState.values, data['printState'])!;
    String? printerIdentifier;
    if (data.containsKey('printerIdentifier'))
      printerIdentifier = data['printerIdentifier'];
    double? progress;
    if (data.containsKey('progress'))
      progress = double.tryParse(data["progress"]);

    double? printingDuration;
    if (data.containsKey('printingDuration'))
      printingDuration = double.tryParse(data["printingDuration"]);
    String? file;
    if (data.containsKey('filename')) file = data['filename'];

    if (state != null && printerIdentifier != null) {
      PrinterSetting? printerSetting = await notificationService._machineService
          .machineFromFcmIdentifier(printerIdentifier);
      if (printerSetting != null) {
        var printState = await notificationService
            ._updatePrintStatusNotification(printerSetting, state, file);
        if (printState == PrintState.printing &&
            progress != null &&
            printingDuration != null)
          await notificationService._updatePrintProgressNotification(
              printerSetting, progress, printingDuration);
        await printerSetting.save();
      }
    }
    notificationService.dispose();
    locator<MachineService>().dispose();
    locator.reset();
  }

  Future<void> initialize() async {
    List<PrinterSetting> allMachines = await _machineService.fetchAll();

    allMachines.forEach(_setupFCMOnPrinterOnceConnected);

    await setupNotificationChannels(allMachines);

    for (PrinterSetting setting in allMachines) {
      registerLocalMessageHandling(setting);
    }

    _hiveStreamListener = setupHiveBoxListener();
    _actionStreamListener = setupNotificationActionListener();
    await setupFirebaseMessaging();
  }

  void registerLocalMessageHandling(PrinterSetting setting) {
    // _logger.w('Currently Disabled local notification handling!');
    // return;

    _printerStreamMap[setting.uuid] = setting.printerService.printerStream
        .listen((value) => _processPrinterUpdate(setting, value));
  }

  StreamSubscription<ReceivedAction> setupNotificationActionListener() {
    return _notifyAPI.actionStream.listen((receivedNotification) =>
        _machineService.selectedMachine.valueOrNull?.websocket
            .ensureConnection());
  }

  StreamSubscription<BoxEvent> setupHiveBoxListener() {
    return _machineService.printerSettingEventStream.listen((event) {
      _logger.d(
          "Received Box-Event<PrinterSetting>: event(${event.key}:${event.value} del=${event.deleted}");
      if (event.deleted)
        onMachineRemoved(event.key);
      else if (!_printerStreamMap.containsKey(event.key)) {
        onMachineAdded(event.value);
      }
    });
  }

  setupNotificationChannels(List<PrinterSetting> machines) async {
    List<NotificationChannelGroup> groups = [];
    List<NotificationChannel> channels = [];
    for (PrinterSetting setting in machines) {
      groups.add(_channelGroupOfPrinterSettings(setting));
      channels.addAll(_channelsOfPrinterSettings(setting));
    }

    await AwesomeNotifications().initialize(
        // set the icon to null if you want to use the default app icon
        null,
        channels,
        channelGroups: groups);

    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        // Insert here your friendly dialog box before call the request method
        // This is very important to not harm the user experience
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
  }

  setupFirebaseMessaging() async {
    if (Platform.isIOS) await FirebaseMessaging.instance.requestPermission();
    FirebaseMessaging.onBackgroundMessage(
        NotificationService._firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen((event) => _logger
        .i("Firebase-FG => ${event.messageId} with payload ${event.data}"));
  }

  Future<void> updatePrintStateOnce() async {
    List<PrinterSetting> allMachines = await _machineService.fetchAll();
    for (PrinterSetting setting in allMachines) {
      PrinterService printerService = setting.printerService;
      await printerService.printerStream.first.then((printer) async {
        _logger.v('Trying to update once for ${setting.name}');
        await _processPrinterUpdate(setting, printer);
      });
    }
  }

  // updatePrintStateOnce() {
  //   Iterable<PrinterSetting> allMachines = _machineService.fetchAll();
  //   _logger.i('Updating PrintState once for BG task?');
  //   for (PrinterSetting setting in allMachines) {
  //     WebSocketWrapper websocket = setting.websocket;
  //     bool connection = websocket.ensureConnection();
  //
  //     _logger.i(
  //         'WS-Connection for ${setting.name} was ${connection ? 'OPEN' : 'CLOSED -  Trying to open again'}');
  //   }
  // }

  onMachineAdded(PrinterSetting setting) {
    List<NotificationChannel> channelsOfPrinterSettings =
        _channelsOfPrinterSettings(setting);
    channelsOfPrinterSettings.forEach((e) => _notifyAPI.setChannel(e));
    _setupFCMOnPrinterOnceConnected(setting);
    registerLocalMessageHandling(setting);
    _logger.i(
        "Added notifications channels and stream-listener for UUID=${setting.uuid}");
  }

  onMachineRemoved(String uuid) {
    _notifyAPI.removeChannel('$uuid-statusUpdates');
    _notifyAPI.removeChannel('$uuid-progressUpdates');
    _printerStreamMap.remove(uuid)?.cancel();
    _logger
        .i("Removed notifications channels and stream-listener for UUID=$uuid");
  }

  List<NotificationChannel> _channelsOfPrinterSettings(
      PrinterSetting printerSetting) {
    return [
      NotificationChannel(
          channelKey: printerSetting.statusUpdatedChannelKey,
          channelName: 'Print Status Updates - ${printerSetting.name}',
          channelDescription: 'Notifications regarding the print status.',
          channelGroupKey: printerSetting.uuid,
          importance: NotificationImportance.Max,
          defaultColor: brownish.shade500),
      NotificationChannel(
          channelKey: printerSetting.printProgressChannelKey,
          channelName: 'Print Progress Updates - ${printerSetting.name}',
          channelDescription: 'Notifications regarding the print progress.',
          channelGroupKey: printerSetting.uuid,
          playSound: false,
          enableVibration: false,
          enableLights: false,
          importance: NotificationImportance.Low,
          defaultColor: brownish.shade500)
    ];
  }

  NotificationChannelGroup _channelGroupOfPrinterSettings(
      PrinterSetting printerSetting) {
    return NotificationChannelGroup(
        channelGroupkey: printerSetting.uuid,
        channelGroupName: 'Printer ${printerSetting.name}');
  }

  Future<void> _setupFCMOnPrinterOnceConnected(PrinterSetting setting) async {
    await setting.websocket.stateStream
        .firstWhere((element) => element == WebSocketState.connected);

    String? fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null) {
      _logger.w("Could not fetch fcm token");
      return Future.error("No token available for device!");
    }
    _logger.i("Devices FCM token: $fcmToken");
    await _machineService.fetchOrCreateFcmIdentifier(setting);
    await _machineService.registerFCMTokenOnMachine(setting, fcmToken);

    // _machineService.registerFCMTokenOnMachineNEW(setting, fcmToken);
  }

  Future<void> _processPrinterUpdate(
      PrinterSetting printerSetting, Printer printer) async {
    var state = await _updatePrintStatusNotification(
        printerSetting, printer.print.state, printer.print.filename, false);

    if (state == PrintState.printing && !Platform.isIOS)
      await _updatePrintProgressNotification(printerSetting,
          printer.virtualSdCard.progress, printer.print.printDuration);
    await printerSetting.save();
  }

  Future<PrintState> _updatePrintStatusNotification(
      PrinterSetting printerSetting,
      PrintState updatedState,
      String? updatedFile,
      [bool createNotification = true]) async {
    PrintState? oldState = printerSetting.lastPrintState;

    if (updatedState == oldState) return updatedState;
    printerSetting.lastPrintState = updatedState;
    _logger.i("Transition update $oldState -> $updatedState");
    if (oldState == null && updatedState != PrintState.printing)
      return updatedState;

    NotificationContent notificationContent = NotificationContent(
      id: Random().nextInt(20000000),
      channelKey: printerSetting.statusUpdatedChannelKey,
      title: 'Print state of ${printerSetting.name} changed!',
      notificationLayout: NotificationLayout.BigText,
    );
    String file = updatedFile ?? 'Unknown';
    switch (updatedState) {
      case PrintState.standby:
        await _removePrintProgressNotification(printerSetting);
        break;
      case PrintState.printing:
        notificationContent.body = 'Started to print file: "$file"';
        printerSetting.lastPrintProgress = null;
        break;
      case PrintState.paused:
        notificationContent.body = 'Paused printing file: "$file"';
        break;
      case PrintState.complete:
        notificationContent.body = 'Finished printing: "$file"';
        await _removePrintProgressNotification(printerSetting);
        break;
      case PrintState.error:
        if (oldState == PrintState.printing) {
          notificationContent.body = 'Error while printing file: "$file"';
          notificationContent.color = Colors.red;
        }
        await _removePrintProgressNotification(printerSetting);
        break;
    }
    if (updatedState != PrintState.standby && createNotification)
      await _notifyAPI.createNotification(content: notificationContent);

    return updatedState;
  }

  Future<void> _removePrintProgressNotification(
          PrinterSetting printerSetting) =>
      _notifyAPI.cancelNotificationsByChannelKey(
          printerSetting.printProgressChannelKey);

  Future<void> _updatePrintProgressNotification(PrinterSetting printerSetting,
      double progress, double printDuration) async {
    if (printerSetting.lastPrintProgress == progress) return;
    printerSetting.lastPrintProgress = progress;
    var dt;
    if (printDuration > 0 && progress > 0) {
      double est = printDuration / progress - printDuration;
      dt = DateTime.now().add(Duration(seconds: est.round()));
    }
    String eta = (dt != null) ? 'ETA: ${DateFormat.Hm().format(dt)}' : '';

    int index = await _machineService.indexOfMachine(printerSetting);
    if (index < 0) return;

    var progressPerc = (progress * 100).floor();
    await _notifyAPI.createNotification(
        content: NotificationContent(
            id: index * 3 + 3,
            channelKey: printerSetting.printProgressChannelKey,
            title: 'Print progress of ${printerSetting.name}',
            body: '$eta $progressPerc%',
            notificationLayout: NotificationLayout.ProgressBar,
            locked: true,
            progress: progressPerc));
  }

  dispose() {
    _hiveStreamListener?.cancel();
    _printerStreamMap.values.forEach((element) => element.cancel());
    _actionStreamListener?.cancel();
  }
}
