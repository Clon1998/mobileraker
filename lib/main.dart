/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/misc_providers.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/service/ui/theme_service.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_logger/src/enums.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as widget;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/app_setup.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/ui/snackbar_service_impl.dart';
import 'package:mobileraker/ui/components/error_card.dart';
import 'package:mobileraker/ui/components/theme_builder.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

import 'service/ui/bottom_sheet_service_impl.dart';
import 'service/ui/dialog_service_impl.dart';
import 'ui/theme/theme_setup.dart';

Future<void> main() async {
  var widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  await setupLogger();
  EasyLocalization.logger.enableLevels = [LevelMessages.error];

  // FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(ProviderScope(
    // Injecting local implementation of interfaces defined in the common module
    overrides: [
      bottomSheetServiceProvider.overrideWith(bottomSheetServiceImpl),
      dialogServiceProvider.overrideWith(dialogServiceImpl),
      snackBarServiceProvider.overrideWith(snackBarServiceImpl),
      themePackProvider.overrideWith(themePacks)
    ],
    observers: const [
      if (kDebugMode) RiverPodLogger(),
    ],
    child: const WarmUp(),
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
          Locale('af'),
          Locale('de'),
          Locale('en'),
          Locale('fr'),
          Locale('hu'),
          Locale('it'),
          Locale('nl'),
          Locale('pt', 'BR'),
          Locale('ro'),
          Locale('ru'),
          Locale('uk'),
          Locale('zh', 'CN'),
          Locale('zh', 'HK'),
        ],
        fallbackLocale: const Locale('en'),
        saveLocale: true,
        useFallbackTranslations: true,
        path: 'assets/translations',
        errorWidget: (e) {
          return MaterialApp(
            home: ErrorCard(
              title: const Text('Can not load languange files!'),
              body: Text(
                  'I am sorry. An unexpected error occured while loading the languange files.\nPlease submit this error to the developer via github: www.github.com/Clon1998/mobileraker\n\n\Error:\n$e'),
            ),
          );
        },
        child: ThemeBuilder(
          builder: (BuildContext context, ThemeData? regularTheme, ThemeData? darkTheme, ThemeMode? themeMode) {
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
    var appLifeCycleNotifier = ref.watch(appLifecycleProvider.notifier);
    var brightness = usePlatformBrightness();
    useOnAppLifecycleStateChange((previous, current) {
      appLifeCycleNotifier.state = current;
    });

    return Container(
      color: splashBgColorForBrightness(brightness),
      child: ref.watch(warmupProviderProvider).when(
            data: (step) {
              if (step == StartUpStep.complete) {
                return const MyApp();
              } else {
                return const _LoadingSplashScreen();
              }
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
    var animCtrler =
        useAnimationController(duration: const Duration(seconds: 1), lowerBound: 0.5, upperBound: 1, initialValue: 1)
          ..repeat(reverse: true);

    return SafeArea(
      child: Directionality(
        textDirection: widget.TextDirection.ltr,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Flexible(
              child: ScaleTransition(
                scale: CurvedAnimation(parent: animCtrler, curve: Curves.elasticInOut),
                child: SvgPicture.asset(
                  'assets/vector/mr_logo.svg',
                  height: 120,
                ),
              ),
            ),
            const Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _EmojiIndicator(),
                  Text(
                    'Created by Patrick Schmidt',
                    style: TextStyle(color: Color(0xff777777)),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _EmojiIndicator extends ConsumerWidget {
  const _EmojiIndicator({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var step = ref.watch(warmupProviderProvider).valueOrNull;
    if (step == null) return const SizedBox.shrink();
    return Text(step.emoji);
  }
}

Color splashBgColorForBrightness(Brightness brightness) =>
    (brightness == Brightness.dark) ? const Color(0xff2A2A2A) : const Color(0xfff7f7f7);
