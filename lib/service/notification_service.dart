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

import 'database_service.dart';
import 'machine_service.dart';

class NotificationService {
  final _logger = getLogger('NotificationService');
  final _machineService = locator<MachineService>();
  final _notifyAPI = AwesomeNotifications();
  Map<String, StreamSubscription<Printer>> _printerStreamMap = {};
  Map<String, StreamSubscription<WebSocketState>> _wsStreamMap = {};
  StreamSubscription<ReceivedAction>? _actionStreamListener;
  StreamSubscription<BoxEvent>? _hiveStreamListener;

  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    // If you're going to use other Firebase services in the background, such as Firestore,
    // make sure you call `initializeApp` before using other Firebase services.

    await setupBoxes();
    setupLocator();
    await locator.allReady();
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

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
      PrinterSetting? printerSetting = notificationService._machineService
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
    Iterable<PrinterSetting> allMachines = _machineService.fetchAll();
    List<NotificationChannelGroup> grps = [];
    List<NotificationChannel> channels = [];
    for (PrinterSetting setting in allMachines) {
      grps.add(_channelGroupOfPrinterSettings(setting));
      channels.addAll(_channelsOfPrinterSettings(setting));
      _wsStreamMap[setting.uuid] =
          setting.websocket.stateStream.listen((WebSocketState value) {
        if (value == WebSocketState.connected) {
          _machineService.fetchOrCreateFcmIdentifier(setting);
          _registerFCMToken(setting);
        }
      });
    }

    await setupNotificationChannels(grps, channels);
    await setupFirebaseMessaging();

    for (PrinterSetting setting in allMachines) {
      _printerStreamMap[setting.uuid] = setting.printerService.printerStream
          .listen((value) => _printerStreamProcessor(setting, value));
    }

    _hiveStreamListener = setupHiveBoxListener();
    _actionStreamListener = setupNotificationActionListener();
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

  Future<String> _registerFCMToken(PrinterSetting printerSetting) async {
    DatabaseService databaseService = printerSetting.databaseService;
    String? fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null) {
      _logger.w("Could not fetch fcm token");
      return Future.error("No token available for device!");
    }

    var item =
        await databaseService.getDatabaseItem('mobileraker', 'fcmTokens');
    if (item == null) {
      _logger.i("Creating fcmTokens in moonraker-Database");
      await databaseService
          .addDatabaseItem('mobileraker', 'fcmTokens', [fcmToken]);
    } else {
      List<String> fcmTokens = List.from(item);
      if (!fcmTokens.contains(fcmToken)) {
        _logger.i("Adding token to existing fcmTokens in moonraker-Database");
        await databaseService.addDatabaseItem(
            'mobileraker', 'fcmTokens', fcmTokens..add(fcmToken));
      }
    }

    return fcmToken;
  }

  setupNotificationChannels(List<NotificationChannelGroup> printerNotifyGrp,
      List<NotificationChannel> printerNotifyChan) async {
    await AwesomeNotifications().initialize(
        // set the icon to null if you want to use the default app icon
        null,
        printerNotifyChan,
        channelGroups: printerNotifyGrp);

    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        // Insert here your friendly dialog box before call the request method
        // This is very important to not harm the user experience
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
  }

  List<NotificationChannel> _channelsOfPrinterSettings(
      PrinterSetting printerSetting) {
    return [
      NotificationChannel(
          channelKey: '${printerSetting.uuid}-statusUpdates',
          channelName: 'Print status updates - ${printerSetting.name}',
          channelDescription: 'Notifications regarding the print progress.',
          channelGroupKey: printerSetting.uuid,
          importance: NotificationImportance.Max,
          defaultColor: brownish.shade500),
      NotificationChannel(
          channelKey: '${printerSetting.uuid}-progressUpdates',
          channelName: 'Print progress updates - ${printerSetting.name}',
          channelDescription: 'Notifications regarding the print progress.',
          channelGroupKey: printerSetting.uuid,
          playSound: false,
          enableVibration: false,
          enableLights: false,
          defaultColor: brownish.shade500)
    ];
  }

  NotificationChannelGroup _channelGroupOfPrinterSettings(
      PrinterSetting printerSetting) {
    return NotificationChannelGroup(
        channelGroupkey: printerSetting.uuid,
        channelGroupName: "Printer ${printerSetting.name}");
  }

  setupFirebaseMessaging() async {
    FirebaseMessaging.onBackgroundMessage(
        NotificationService._firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen((event) => _logger
        .i("Firebase-FG => ${event.messageId} with payload ${event.data}"));
    if (Platform.isIOS) await FirebaseMessaging.instance.requestPermission();
  }

  Future<void> updatePrintStateOnce() async {
    Iterable<PrinterSetting> allMachines = _machineService.fetchAll();
    for (PrinterSetting setting in allMachines) {
      PrinterService printerService = setting.printerService;
      await printerService.printerStream.first.then((printer) async {
        _logger.v('Trying to update once for ${setting.name}');
        await _printerStreamProcessor(setting, printer);
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

    _wsStreamMap[setting.uuid] =
        setting.websocket.stateStream.listen((WebSocketState value) {
      if (value == WebSocketState.connected) {
        _machineService.fetchOrCreateFcmIdentifier(setting);
        _registerFCMToken(setting);
      }
    });
    _printerStreamMap[setting.uuid] = setting.printerService.printerStream
        .listen((value) => _printerStreamProcessor(setting, value));
    _logger.i(
        "Added notifications channels and stream-listener for UUID=${setting.uuid}");
  }

  onMachineRemoved(String uuid) {
    _notifyAPI.removeChannel('$uuid-statusUpdates');
    _notifyAPI.removeChannel('$uuid-progressUpdates');
    _printerStreamMap.remove(uuid)?.cancel();
    _wsStreamMap.remove(uuid)?.cancel();
    _logger
        .i("Removed notifications channels and stream-listener for UUID=$uuid");
  }

  Future<void> _printerStreamProcessor(
      PrinterSetting printerSetting, Printer printer) async {
    var state = await _updatePrintStatusNotification(
        printerSetting, printer.print.state, printer.print.filename);

    if (state == PrintState.printing)
      _updatePrintProgressNotification(printerSetting,
          printer.virtualSdCard.progress, printer.print.printDuration);
    await printerSetting.save();
  }

  Future<PrintState> _updatePrintStatusNotification(
      PrinterSetting printerSetting, PrintState state, String? file) async {
    PrintState? oldState = printerSetting.lastPrintState;

    if (state == oldState) return state;
    printerSetting.lastPrintState = state;
    _logger.i("Transition update $oldState -> $state");
    if (oldState == null && state != PrintState.printing) return state;

    switch (state) {
      case PrintState.standby:
        await _removePrintProgressNotification(printerSetting);
        break;
      case PrintState.printing:
        await _notifyAPI.createNotification(
            content: NotificationContent(
          id: Random().nextInt(20000000),
          channelKey: '${printerSetting.uuid}-statusUpdates',
          title: 'Print state of ${printerSetting.name} changed!',
          body: 'Started to print file: "${file ?? "UNKNOWN"}"',
          notificationLayout: NotificationLayout.BigText,
        ));
        printerSetting.lastPrintProgress = null;
        break;
      case PrintState.paused:
        await _notifyAPI.createNotification(
            content: NotificationContent(
          id: Random().nextInt(20000000),
          channelKey: '${printerSetting.uuid}-statusUpdates',
          title: 'Print state of ${printerSetting.name} changed!',
          body: 'Paused printing of file: "${file ?? "UNKNOWN"}"',
          notificationLayout: NotificationLayout.BigText,
        ));
        break;
      case PrintState.complete:
        await _notifyAPI.createNotification(
            content: NotificationContent(
          id: Random().nextInt(20000000),
          channelKey: '${printerSetting.uuid}-statusUpdates',
          title: 'Print state of ${printerSetting.name} changed!',
          body: 'Finished printing "${file ?? "UNKNOWN"}"',
          notificationLayout: NotificationLayout.BigText,
        ));

        await _removePrintProgressNotification(printerSetting);
        break;
      case PrintState.error:
        if (oldState == PrintState.printing)
          await _notifyAPI.createNotification(
              content: NotificationContent(
                  id: Random().nextInt(20000000),
                  channelKey: '${printerSetting.uuid}-statusUpdates',
                  title: 'Print state of ${printerSetting.name} changed!',
                  body: 'Error while printing file: "${file ?? "UNKNOWN"}"',
                  notificationLayout: NotificationLayout.BigText,
                  color: Colors.red));
        await _removePrintProgressNotification(printerSetting);
        break;
    }
    return state;
  }

  Future<void> _removePrintProgressNotification(
          PrinterSetting printerSetting) =>
      _notifyAPI.cancelNotificationsByChannelKey(
          '${printerSetting.uuid}-progressUpdates');

  Future<void> _updatePrintProgressNotification(PrinterSetting printerSetting,
      double progress, double printDuration) async {
    if (printerSetting.lastPrintProgress == progress) return;
    printerSetting.lastPrintProgress = progress;
    var dt;
    if (printDuration > 0 && progress > 0) {
      double est = printDuration / progress - printDuration;
      dt = DateTime.now().add(Duration(seconds: est.round()));
    }
    String eta = (dt != null) ? 'ETA:${DateFormat.Hm().format(dt)}' : '';

    int index = _machineService.indexOfMachine(printerSetting);
    if (index < 0) return;

    var progressPerc = (progress * 100).floor();
    await _notifyAPI.createNotification(
        content: NotificationContent(
            id: index * 3 + 3,
            channelKey: '${printerSetting.uuid}-progressUpdates',
            title: 'Print progress of ${printerSetting.name}',
            body: '$eta $progressPerc%',
            notificationLayout: NotificationLayout.ProgressBar,
            locked: true,
            progress: progressPerc));
  }

  dispose() {
    _hiveStreamListener?.cancel();
    _printerStreamMap.values.forEach((element) => element.cancel());
    _wsStreamMap.values.forEach((element) => element.cancel());
    _actionStreamListener?.cancel();
  }
}
