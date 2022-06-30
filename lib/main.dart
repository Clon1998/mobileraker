import 'package:easy_localization/easy_localization.dart';
import 'package:easy_logger/src/enums.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:logger/logger.dart';
import 'package:mobileraker/app/app_setup.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/firebase_options.dart';
import 'package:mobileraker/service/notification_service.dart';
import 'package:mobileraker/ui/components/bottomsheet/setup_bottom_sheet_ui.dart';
import 'package:mobileraker/ui/components/dialog/setup_dialog_ui.dart';
import 'package:mobileraker/ui/components/snackbar/setup_snackbar.dart';
import 'package:mobileraker/ui/components/theme_builder.dart';
import 'package:mobileraker/ui/theme_setup.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app/app_setup.router.dart';

String? initialRoute;

Future<void> main() async {
  Logger.level = Level.info;
  EasyLocalization.logger.enableLevels = [LevelMessages.error];
  WidgetsFlutterBinding.ensureInitialized();
  await setupBoxes();
  setupLocator();
  await locator.allReady();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate();
  await EasyLocalization.ensureInitialized();
  await locator<NotificationService>().initialize();
  setupSnackbarUi();
  setupDialogUi();
  setupBottomSheetUi();
  await FirebaseAnalytics.instance.logAppOpen();
  await setupCat();

  setupLicenseRegistry();
  initialRoute = await selectInitialRoute();
  runApp(EasyLocalization(
      child: MyApp(),
      supportedLocales: [
        Locale('en'),
        Locale('de'),
        Locale('hu'),
        Locale('zh', 'CN'),
        Locale('zh', 'HK')
      ],
      fallbackLocale: Locale('en'),
      saveLocale: true,
      useFallbackTranslations: true,
      path: 'assets/translations'));
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ThemeBuilder(
      themePacks: getThemePacks(context),
      builder: (BuildContext context, ThemeData? regularTheme,
          ThemeData? darkTheme, ThemeMode? themeMode) {
        return MaterialApp(
          title: 'Mobileraker',
          theme: regularTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          navigatorKey: StackedService.navigatorKey,
          onGenerateRoute: StackedRouter().onGenerateRoute,
          initialRoute: initialRoute,
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FormBuilderLocalizations.delegate,
            ...context.localizationDelegates,
            RefreshLocalizations.delegate,
          ],
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          navigatorObservers: [
            StackedService.routeObserver,
            FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
          ],
        );
      },
    );
  }
}
