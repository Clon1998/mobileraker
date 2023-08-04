/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:easy_logger/src/enums.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/app_setup.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/ui/components/error_card.dart';
import 'package:mobileraker/ui/components/theme_builder.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

import 'logger.dart';

Future<void> main() async {
  setupLogger();
  EasyLocalization.logger.enableLevels = [LevelMessages.error];
  var widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(const ProviderScope(
    observers: [
      if (kDebugMode) RiverPodLogger(),
    ],
    child: WarmUp(),
  ));
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
          builder: (BuildContext context, ThemeData? regularTheme, ThemeData? darkTheme,
              ThemeMode? themeMode) {
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

class WarmUp extends HookConsumerWidget {
  const WarmUp({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var brightness = usePlatformBrightness();
    return Container(
      color: splashBgColorForBrightness(brightness),
      child: ref.watch(warmupProviderProvider).when(
            data: (_) {
              return const MyApp();
            },
            error: (e, s) {
              return MaterialApp(
                home: ErrorCard(
                  title: const Text('Error while starting Mobileraker!'),
                  body: Text(
                      'I am sorry...\nSomething unexpected happed.\nPlease report this bug to the developer!\n\n$e\n$s'),
                ),
              );
            },
            loading: () => const _LoadingSplashScreen(),
          ),
    );
  }
}

class _LoadingSplashScreen extends HookWidget {
  const _LoadingSplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var animCtrler = useAnimationController(
        duration: const Duration(seconds: 1), lowerBound: 0.5, upperBound: 1, initialValue: 1)
      ..repeat(reverse: true);

    return Center(
      child: ScaleTransition(
        scale: CurvedAnimation(parent: animCtrler, curve: Curves.elasticInOut),
        child: SvgPicture.asset(
          'assets/vector/mr_logo.svg',
          height: 120,
        ),
      ),
    );
  }
}

Color splashBgColorForBrightness(Brightness brightness) =>
    (brightness == Brightness.dark) ? const Color(0xff2A2A2A) : const Color(0xfff7f7f7);
