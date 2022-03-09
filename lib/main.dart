import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:logger/logger.dart';
import 'package:mobileraker/app/app_setup.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/firebase_options.dart';
import 'package:mobileraker/service/notification_service.dart';
import 'package:mobileraker/ui/bottomsheet/setup_bottom_sheet_ui.dart';
import 'package:mobileraker/ui/dialog/setup_dialog_ui.dart';
import 'package:mobileraker/ui/snackbar/setup_snackbar.dart';
import 'package:mobileraker/ui/theme_setup.dart';
import 'package:stacked_services/stacked_services.dart';

import 'app/app_setup.router.dart';

Future<void> main() async {
  Logger.level = Level.info;
  // EasyLocalization.logger.enableLevels = [LevelMessages.info];
  WidgetsFlutterBinding.ensureInitialized();
  await setupBoxes();
  setupLocator();
  await locator.allReady();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await locator<NotificationService>().initialize();
  await EasyLocalization.ensureInitialized();
  setupSnackbarUi();
  setupDialogUi();
  setupBottomSheetUi();
  await FirebaseAnalytics.instance.logAppOpen();
  final _navigationService = locator<NavigationService>();
  runApp(EasyLocalization(
      child: MyApp(),
      supportedLocales: [Locale('en'), Locale('de')],
      fallbackLocale: Locale('en'),
      path: 'assets/translations'));
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Mobileraker',
        theme: getLightTheme(),
        darkTheme: getDarkTheme(),
        navigatorKey: StackedService.navigatorKey,
        onGenerateRoute: StackedRouter().onGenerateRoute,
        localizationsDelegates: [
          FormBuilderLocalizations.delegate,
          ...context.localizationDelegates
        ],
        supportedLocales: context.supportedLocales,
        locale: context.locale,
      );
  }
}
