import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:mobileraker/app/app_setup.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/service/notification_service.dart';
import 'package:mobileraker/ui/bottomsheet/setup_bottom_sheet_ui.dart';
import 'package:mobileraker/ui/dialog/setup_dialog_ui.dart';
import 'package:mobileraker/ui/theme_setup.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:workmanager/workmanager.dart';

import 'app/app_setup.router.dart';

Future<void> main() async {
  Logger.level = Level.info;
  await openBoxes();
  setupLocator();
  await locator.allReady();
  await setupNotifications();
  locator<NotificationService>().initialize();

  setupDialogUi();
  setupBottomSheetUi();

  await Workmanager().initialize(
      callbackDispatcher, // The top level function, aka callbackDispatcher
      isInDebugMode:
          false // If enabled it will post a notification whenever the task is running. Handy for debugging tasks
      );

  if (Platform.isAndroid)
    await Workmanager().registerPeriodicTask(
      "1",
      "periodicPrintStatusTask",
      frequency: Duration(minutes: 15),
    );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Mobileraker',
        theme: getLightTheme(),
        darkTheme: getDarkTheme(),
        navigatorKey: StackedService.navigatorKey,
        onGenerateRoute: StackedRouter().onGenerateRoute,
      );
}
