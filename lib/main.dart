/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:easy_logger/src/enums.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/firebase/analytics.dart';
import 'package:mobileraker/service/notification_service.dart';
import 'package:mobileraker/service/payment_service.dart';
import 'package:mobileraker/ui/components/theme_builder.dart';
import 'package:mobileraker_pro/mobileraker_pro.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

import 'app_setup.dart';
import 'logger.dart';

Future<void> main() async {
  setupLogger();

  EasyLocalization.logger.enableLevels = [LevelMessages.error];
  WidgetsFlutterBinding.ensureInitialized();
  await setupBoxes();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack);
    return true;
  };

  // FirebaseCrashlytics.instance.sendUnsentReports();
  if (kDebugMode) {
    FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
  }

  await FirebaseAppCheck.instance.activate();
  await EasyLocalization.ensureInitialized();

  setupLicenseRegistry();
  final container = ProviderContainer(
    observers: [
      if (kDebugMode) const RiverPodLogger(),
    ],
  );

  await container.read(analyticsProvider).logAppOpen();

  // await for the initial rout provider to be ready and setup!
  await container.read(initialRouteProvider.future);
  await initializeAvailableMachines(container);
  await trackInitialMachineCount(container);

  await container.read(notificationServiceProvider).initialize();
  await container.read(paymentServiceProvider).initialize();
  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(goRouterProvider);
    return EasyLocalization(
        supportedLocales: const [
          Locale('de'),
          Locale('en'),
          Locale('fr'),
          Locale('hu'),
          Locale('it'),
          Locale('nl'),
          Locale('ro'),
          Locale('ru'),
          Locale('zh', 'CN'),
          Locale('zh', 'HK'),
        ],
        fallbackLocale: const Locale('en'),
        saveLocale: true,
        useFallbackTranslations: true,
        path: 'assets/translations',
        child: ThemeBuilder(
          builder: (BuildContext context, ThemeData? regularTheme,
              ThemeData? darkTheme, ThemeMode? themeMode) {
            return MaterialApp.router(
              routerDelegate: goRouter.routerDelegate,
              routeInformationProvider: goRouter.routeInformationProvider,
              routeInformationParser: goRouter.routeInformationParser,
              title: 'Mobileraker',
              theme: regularTheme,
              darkTheme: darkTheme,
              themeMode: themeMode,
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
            );
          },
        ));
  }
}
