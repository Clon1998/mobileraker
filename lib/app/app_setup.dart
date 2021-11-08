import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/domain/temperature_preset.dart';
import 'package:mobileraker/domain/webcam_setting.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/notification_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/views/files/details/file_details_view.dart';
import 'package:mobileraker/ui/views/files/files_view.dart';
import 'package:mobileraker/ui/views/fullcam/full_cam_view.dart';
import 'package:mobileraker/ui/views/overview/overview_view.dart';
import 'package:mobileraker/ui/views/overview/tabs/general_tab_viewmodel.dart';
import 'package:mobileraker/ui/views/printers/add/printers_add_view.dart';
import 'package:mobileraker/ui/views/printers/edit/printers_edit_view.dart';
import 'package:mobileraker/ui/views/setting/setting_view.dart';
import 'package:stacked/stacked_annotations.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:workmanager/workmanager.dart';

import 'app_setup.logger.dart';

@StackedApp(routes: [
  MaterialRoute(page: OverView, initial: true),
  MaterialRoute(page: FullCamView),
  MaterialRoute(page: PrintersAdd),
  MaterialRoute(page: PrintersEdit),
  MaterialRoute(page: FilesView),
  MaterialRoute(page: FileDetailView),
  MaterialRoute(page: SettingView),
], dependencies: [
  LazySingleton(classType: NavigationService),
  LazySingleton(classType: SnackbarService),
  LazySingleton(classType: DialogService),
  LazySingleton(classType: BottomSheetService),
  LazySingleton(classType: GeneralTabViewModel),
  Singleton(classType: MachineService),
  Singleton(classType: SettingService),
  Singleton(classType: NotificationService),
], logger: StackedLogger())
class AppSetup {}

openBoxes() async {
  await Hive.initFlutter();
  Hive.registerAdapter(PrinterSettingAdapter());
  Hive.registerAdapter(WebcamSettingAdapter());
  Hive.registerAdapter(TemperaturePresetAdapter());
  // Hive.deleteBoxFromDisk('printers');
  await Future.wait([
    Hive.openBox<PrinterSetting>('printers'),
    Hive.openBox<String>('uuidbox'),
    Hive.openBox('settingsbox'),
  ]);
}

setupNotifications() async {
  await AwesomeNotifications().initialize(
      // set the icon to null if you want to use the default app icon
      null,
      [
        NotificationChannel(
            channelKey: 'basic_channel',
            channelName: 'Basic notifications',
            channelDescription: 'Notification channel for basic tests',
            defaultColor: Color(0xFF9D50DD),
            ledColor: Colors.white),
        NotificationChannel(
            channelKey: 'printStatusUpdate_channel',
            importance: NotificationImportance.Max,
            channelName: 'Print status update notifications',
            channelDescription: 'Notifications regarding the print progress.',
            defaultColor: Color(0xFF9D50DD),
            ledColor: Colors.white),
        NotificationChannel(
            channelKey: 'printStatusProgress_channel',
            channelName: 'Print status progress notifications',
            channelDescription: 'Notifications regarding the print progress.',
            playSound: false,
            enableVibration: false,
            enableLights: false,
            defaultColor: Color(0xFF9D50DD),
            ledColor: Colors.white),
      ]);

  await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
    if (!isAllowed) {
      // Insert here your friendly dialog box before call the request method
      // This is very important to not harm the user experience
      AwesomeNotifications().requestPermissionToSendNotifications();
    }
  });
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    Logger.level = Level.info;
    final _logger = getLogger('Workmanager.executeTask');

    try {
      _logger.i('Received Task $task');
      switch (task) {
        case Workmanager.iOSBackgroundTask:
        case 'periodicPrintStatusTask':
          _logger.i('Executing update stuff');
          await openBoxes();
          setupLocator();
          await locator.allReady();
          await setupNotifications();

          NotificationService notificationService =
              locator<NotificationService>();
          await notificationService.updatePrintStateOnce();
          _logger.i('Disposing services again');
          notificationService.dispose();
          locator<MachineService>().dispose();
          break;
        default:
          _logger.i('Default code branche');
      }
    } catch (err, stacktrace) {
      _logger.e('Catched error \n $err \n \$stacktrace', err, stacktrace);
      AwesomeNotifications().createNotification(
          content: NotificationContent(
              id: 55,
              channelKey: 'basic_channel',
              title: 'BG-Fetching-Error',
              notificationLayout: NotificationLayout.BigText,
              body: '$err\n\n $stacktrace}'));
    }

    return Future.value(true);
  });
}
