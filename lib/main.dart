import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:mobileraker/app/AppSetup.dart';
import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:stacked_services/stacked_services.dart';

import 'app/AppSetup.router.dart';

Future<void> main() async {
  await Settings.init();
  setupLocator();
  registerPrinters();
  setupDialogUi();
  setupNotifications();
  runApp(MyApp());

  AwesomeNotifications().actionStream.listen((receivedNotification) {
    print("Received Press-Notifi:$receivedNotification");
    // Navigator.of(context).pushName(context,
    //     '/NotificationPage',
    //     arguments: { id: receivedNotification.id } // your page params. I recommend to you to pass all *receivedNotification* object
    // );
  });
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      navigatorKey: StackedService.navigatorKey,
      onGenerateRoute: StackedRouter().onGenerateRoute,
    );
  }
}
