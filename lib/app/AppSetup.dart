import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:mobileraker/WsHelper.dart';
import 'package:mobileraker/service/KlippyService.dart';
import 'package:mobileraker/service/PrinterService.dart';
import 'package:mobileraker/ui/dialog/editForm/editForm_view.dart';
import 'package:mobileraker/ui/overview/overview_view.dart';
import 'package:mobileraker/ui/setting/setting_view.dart';
import 'package:mobileraker/ui/test_view.dart';
import 'package:simple_logger/simple_logger.dart';
import 'package:stacked/stacked_annotations.dart';
import 'package:stacked_services/stacked_services.dart';

import 'AppSetup.locator.dart';

@StackedApp(routes: [
  MaterialRoute(page: OverView, initial: true),
  CupertinoRoute(page: SettingView),
  CupertinoRoute(page: TestView),
], dependencies: [
  LazySingleton(classType: NavigationService),
  LazySingleton(classType: SnackbarService),
  LazySingleton(classType: DialogService),
  LazySingleton(classType: PrinterService),
  LazySingleton(classType: KlippyService),
  LazySingleton(classType: SimpleLogger),
  Singleton(classType: WebSocketsNotifications),
])
class AppSetup {}

enum DialogType { editForm, connectionError }

void setupDialogUi() {
  final dialogService = locator<DialogService>();

  final builders = {
    DialogType.editForm: (context, sheetRequest, completer) =>
        FormDialogView(request: sheetRequest, completer: completer),
  };
  dialogService.registerCustomDialogBuilders(builders);
}

void setupLogger() {
  final logger = locator<SimpleLogger>();

  logger.setLevel(Level.INFO);
}

void setupNotifications() {
  AwesomeNotifications().initialize(
    // set the icon to null if you want to use the default app icon
      null,
      [
        NotificationChannel(
            channelKey: 'basic_channel',
            channelName: 'Basic notifications',
            channelDescription: 'Notification channel for basic tests',
            defaultColor: Color(0xFF9D50DD),
            ledColor: Colors.white
        )
      ]
  );

  AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
    if (!isAllowed) {
      // Insert here your friendly dialog box before call the request method
      // This is very important to not harm the user experience
      AwesomeNotifications().requestPermissionToSendNotifications();
    }
  });
}
