import 'dart:async';
import 'dart:io';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobileraker/app_setup.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/hive/progress_notification_mode.dart';
import 'package:mobileraker/firebase_options.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/theme/theme_setup.dart';

import 'machine_service.dart';

final awesomeNotificationProvider =
    Provider<AwesomeNotifications>((ref) => AwesomeNotifications());

final notificationServiceProvider =
    Provider.autoDispose<NotificationService>((ref) {
  ref.keepAlive();
  var notificationService = NotificationService(ref);
  ref.onDispose(notificationService.dispose);
  return notificationService;
});

class NotificationService {
  NotificationService(this.ref)
      : _machineService = ref.watch(machineServiceProvider),
        _settingsService = ref.watch(settingServiceProvider),
        _notifyAPI = ref.watch(awesomeNotificationProvider);

  final AutoDisposeRef ref;
  final MachineService _machineService;
  final SettingService _settingsService;
  final AwesomeNotifications _notifyAPI;
  final Map<String, ProviderSubscription<AsyncValue<Printer>>>
      _printerStreamMap = {};
  StreamSubscription<ReceivedAction>? _actionStreamListener;
  StreamSubscription<BoxEvent>? _hiveStreamListener;

  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    // If you're going to use other Firebase services in the background, such as Firestore,
    // make sure you call `initializeApp` before using other Firebase services.
    DartPluginRegistrant.ensureInitialized();
    if (Platform.isAndroid) {
      // Only for Android a isolate is spawned!
      await setupBoxes();
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    }
    ProviderContainer container = ProviderContainer();
    NotificationService notificationService =
        container.read(notificationServiceProvider);
    logger.d(
        "Handling a background message: ${message.messageId} with ${message.data}");
    Map<String, dynamic> data = message.data;
    PrintState? state;
    if (data.containsKey('printState')) {
      state = EnumToString.fromString(PrintState.values, data['printState'])!;
    }
    String? printerIdentifier;
    if (data.containsKey('printerIdentifier')) {
      printerIdentifier = data['printerIdentifier'];
    }
    double? progress;
    if (data.containsKey('progress')) {
      progress = double.tryParse(data["progress"]);
    }

    double? printingDuration;
    if (data.containsKey('printingDuration')) {
      printingDuration = double.tryParse(data["printingDuration"]);
    }
    String? file;
    if (data.containsKey('filename')) file = data['filename'];

    if (state != null && printerIdentifier != null) {
      Machine? machine = await notificationService._machineService
          .machineFromFcmIdentifier(printerIdentifier);
      if (machine != null) {
        var printState = await notificationService
            ._updatePrintStatusNotification(machine, state, file);
        if (printState == PrintState.printing &&
            progress != null &&
            printingDuration != null) {
          await notificationService._updatePrintProgressNotification(
              machine, progress, printingDuration);
        }
        await machine.save();
      }
    }
    container.dispose();
  }

  Future<void> initialize() async {
    List<Machine> allMachines = await _machineService.fetchAll();

    allMachines.forEach(_setupFCMOnPrinterOnceConnected);

    await setupNotificationChannels(allMachines);

    await initialRequestPermission();

    for (Machine setting in allMachines) {
      registerLocalMessageHandling(setting);
    }

    _hiveStreamListener = setupHiveBoxListener();
    _actionStreamListener = setupNotificationActionListener();
    await setupFirebaseMessaging();
  }

  Future<bool> initialRequestPermission() async {
    bool notificationAllowed = await hasNotificationPermission();
    logger.i('Notifications are permitted: $notificationAllowed');

    if (_settingsService.readBool(requestedNotifyPermission, true)) {
      return notificationAllowed;
    }
    if (!notificationAllowed) {
      return requestNotificationPermission();
    }
    return notificationAllowed;
  }

  Future<bool> requestNotificationPermission() async {
    await _settingsService.writeBool(requestedNotifyPermission, true);
    return _notifyAPI.requestPermissionToSendNotifications();
  }

  Future<bool> hasNotificationPermission() {
    var notificationAllowed = _notifyAPI.isNotificationAllowed();
    return notificationAllowed;
  }

  registerLocalMessageHandling(Machine setting) {
    _printerStreamMap[setting.uuid] = ref.listen(printerProvider(setting.uuid),
        (previous, AsyncValue<Printer> next) {
      next.whenData((value) => _processPrinterUpdate(setting, value));
    });
  }

  StreamSubscription<ReceivedAction> setupNotificationActionListener() {
    //TODO: Swap to active printer that issued the notification!
    return _notifyAPI.actionStream.listen((receivedNotification) {
      ref
          .read(selectedMachineProvider)
          .whenData((value) => ref.read(jrpcClientProvider(value!.uuid)));
    });
  }

  StreamSubscription<BoxEvent> setupHiveBoxListener() {
    return _machineService.machineEventStream.listen((event) {
      logger.d(
          "Received Box-Event<machine>: event(${event.key}:${event.value} del=${event.deleted}");
      if (event.deleted) {
        onMachineRemoved(event.key);
      } else if (!_printerStreamMap.containsKey(event.key)) {
        onMachineAdded(event.value);
      }
    });
  }

  setupNotificationChannels(List<Machine> machines) async {
    List<NotificationChannelGroup> groups = [];
    List<NotificationChannel> channels = [];
    for (Machine setting in machines) {
      groups.add(_channelGroupOfmachines(setting));
      channels.addAll(_channelsOfmachines(setting));
    }

    await _notifyAPI.initialize(
        // set the icon to null if you want to use the default app icon
        null,
        channels,
        channelGroups: groups);
  }

  setupFirebaseMessaging() async {
    if (Platform.isIOS) await FirebaseMessaging.instance.requestPermission();
    FirebaseMessaging.onBackgroundMessage(
        NotificationService._firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen((event) => logger
        .i("Firebase-FG => ${event.messageId} with payload ${event.data}"));
  }

  Future<void> updatePrintStateOnce() async {
    List<Machine> allMachines = await _machineService.fetchAll();
    for (Machine machine in allMachines) {
      ref.read(printerProvider(machine.uuid)).whenData((value) {
        _processPrinterUpdate(machine, value);
      });
    }
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

  onMachineAdded(Machine setting) {
    List<NotificationChannel> channelsOfmachines = _channelsOfmachines(setting);
    for (var channels in channelsOfmachines) {
      _notifyAPI.setChannel(channels);
    }
    _setupFCMOnPrinterOnceConnected(setting);
    registerLocalMessageHandling(setting);
    logger.i(
        "Added notifications channels and stream-listener for UUID=${setting.uuid}");
  }

  onMachineRemoved(String uuid) {
    _notifyAPI.removeChannel('$uuid-statusUpdates');
    _notifyAPI.removeChannel('$uuid-progressUpdates');
    _printerStreamMap.remove(uuid)?.close();
    logger
        .i("Removed notifications channels and stream-listener for UUID=$uuid");
  }

  List<NotificationChannel> _channelsOfmachines(Machine machine) {
    return [
      NotificationChannel(
          channelKey: machine.statusUpdatedChannelKey,
          channelName: 'Print Status Updates - ${machine.name}',
          channelDescription: 'Notifications regarding the print status.',
          channelGroupKey: machine.uuid,
          importance: NotificationImportance.Max,
          defaultColor: brownish.shade500),
      NotificationChannel(
          channelKey: machine.printProgressChannelKey,
          channelName: 'Print Progress Updates - ${machine.name}',
          channelDescription: 'Notifications regarding the print progress.',
          channelGroupKey: machine.uuid,
          playSound: false,
          enableVibration: false,
          enableLights: false,
          importance: NotificationImportance.Low,
          defaultColor: brownish.shade500)
    ];
  }

  NotificationChannelGroup _channelGroupOfmachines(Machine machine) {
    return NotificationChannelGroup(
        channelGroupkey: machine.uuid,
        channelGroupName: 'Printer ${machine.name}');
  }

  _setupFCMOnPrinterOnceConnected(Machine machine) async {
    late ProviderSubscription<AsyncValue<ClientState>> sub;
    sub = ref.listen(
        jrpcClientStateProvider(machine.uuid),
        (previous, AsyncValue<ClientState> next) =>
            next.whenData((value) async {
              if (value != ClientState.connected) return;
              try {
                String? fcmToken = await FirebaseMessaging.instance.getToken();
                if (fcmToken == null) {
                  logger.w("Could not fetch fcm token");
                  return Future.error("No token available for device!");
                }
                logger.i("Device's FCM token: $fcmToken");

                await _machineService.fetchOrCreateFcmIdentifier(machine);
                await _machineService.registerFCMTokenOnMachine(
                    machine, fcmToken);
                // _machineService.registerFCMTokenOnMachineNEW(setting, fcmToken);
              } catch (e, s) {
                logger.w(
                    'Could not setupFCM on ${machine.name}(${machine.wsUrl})',
                    null,
                    s);
              } finally {
                sub.close();
              }
            }),
        fireImmediately: true);
  }

  Future<void> _processPrinterUpdate(Machine machine, Printer printer) async {
    var state = await _updatePrintStatusNotification(
        machine, printer.print.state, printer.print.filename, false);

    if (state == PrintState.printing && !Platform.isIOS) {
      await _updatePrintProgressNotification(machine,
          printer.virtualSdCard.progress, printer.print.printDuration, false);
    }
    await machine.save();
  }

  Future<PrintState> _updatePrintStatusNotification(
      Machine machine, PrintState updatedState, String? updatedFile,
      [bool createNotification = true]) async {
    PrintState? oldState = machine.lastPrintState;

    if (updatedState == oldState) return updatedState;
    machine.lastPrintState = updatedState;
    logger.i("Transition update $oldState -> $updatedState");
    if (oldState == null && updatedState != PrintState.printing) {
      return updatedState;
    }

    NotificationContent notificationContent = NotificationContent(
      id: Random().nextInt(20000000),
      channelKey: machine.statusUpdatedChannelKey,
      title: 'Print state of ${machine.name} changed!',
      notificationLayout: NotificationLayout.BigText,
    );
    String file = updatedFile ?? 'Unknown';
    switch (updatedState) {
      case PrintState.standby:
        await _removePrintProgressNotification(machine);
        break;
      case PrintState.printing:
        notificationContent.body = 'Started to print file: "$file"';
        machine.lastPrintProgress = null;
        break;
      case PrintState.paused:
        notificationContent.body = 'Paused printing file: "$file"';
        break;
      case PrintState.complete:
        notificationContent.body = 'Finished printing: "$file"';
        await _removePrintProgressNotification(machine);
        break;
      case PrintState.error:
        if (oldState == PrintState.printing) {
          notificationContent.body = 'Error while printing file: "$file"';
          notificationContent.color = Colors.red;
        }
        await _removePrintProgressNotification(machine);
        break;
    }
    if (updatedState != PrintState.standby && createNotification) {
      await _notifyAPI.createNotification(content: notificationContent);
    }

    return updatedState;
  }

  Future<void> _removePrintProgressNotification(Machine machine) => _notifyAPI
      .cancelNotificationsByChannelKey(machine.printProgressChannelKey);

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

  Future<void> _updatePrintProgressNotification(
      Machine machine, double progress, double printDuration,
      [bool normalize = true]) async {
    if (progress >= 100) return;

    int readInt = _settingsService.readInt(selectedProgressNotifyMode, -1);

    ProgressNotificationMode progMode = readInt >= 0
        ? ProgressNotificationMode.values[readInt]
        : ProgressNotificationMode.TWENTY_FIVE;

    if (progMode == ProgressNotificationMode.DISABLED) return;

    double normalizedProgress =
        normalize ? normalizeProgress(progMode, progress) : progress;

    if (machine.lastPrintProgress == normalizedProgress) return;
    machine.lastPrintProgress = normalizedProgress;
    var dt;
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

  dispose() {
    _hiveStreamListener?.cancel();
    _printerStreamMap.values.forEach((element) => element.close());
    _actionStreamListener?.cancel();
  }
}
