import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:mobileraker/app/app_setup.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/ui/bottomsheet/setup_bottom_sheet_ui.dart';
import 'package:mobileraker/ui/dialog/setup_dialog_ui.dart';
import 'package:stacked_services/stacked_services.dart';

import 'app/app_setup.router.dart';

Future<void> main() async {
  Logger.level = Level.info;

  await openBoxes();
  setupLocator();
  setupDialogUi();
  setupBottomSheetUi();

  setupNotifications();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    var accentColorDarkTheme = Color.fromRGBO(178, 24, 24, 1);
    return MaterialApp(
      title: 'Mobileraker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        toggleButtonsTheme: ToggleButtonsThemeData(
            fillColor: accentColorDarkTheme, selectedColor: Colors.white),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(primary: accentColorDarkTheme),
        ),
        // primarySwatch: Colors.orange,
        accentColor: accentColorDarkTheme,
      ),
      navigatorKey: StackedService.navigatorKey,
      onGenerateRoute: StackedRouter().onGenerateRoute,
    );
  }
}
