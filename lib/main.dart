/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/misc_providers.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/service/ui/theme_service.dart';
import 'package:common/ui/components/error_card.dart';
import 'package:common/ui/locale_spy.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_logger/src/enums.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'package:mobileraker/ui/components/responsive_builder.dart';
import 'package:mobileraker/ui/components/theme_builder.dart';
import 'package:mobileraker_pro/mobileraker_pro.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

import 'service/ui/bottom_sheet_service_impl.dart';
import 'service/ui/dialog_service_impl.dart';
import 'ui/theme/theme_setup.dart';

Future<void> main() async {
  var widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await setupLogger();
  EasyLocalization.logger.enableLevels = [LevelMessages.error];
  logger.i('-----------------------');
  logger.i('Starting Mobileraker...');
  logger.i('-----------------------');
  // FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(ProviderScope(
    // Injecting local implementation of interfaces defined in the common module
    overrides: [
      bottomSheetServiceProvider.overrideWith(bottomSheetServiceImpl),
      dialogServiceProvider.overrideWith(dialogServiceImpl),
      snackBarServiceProvider.overrideWith(snackBarServiceImpl),
      themePackProvider.overrideWith(themePacks),
      goRouterProvider.overrideWith(goRouterImpl),
    ],
    observers: const [if (kDebugMode) RiverPodLogger()],
    child: const _WarmUp(),
  ));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

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
        Locale('tr'),
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
              'I am sorry. An unexpected error occured while loading the languange files.\nPlease submit this error to the developer via github: www.github.com/Clon1998/mobileraker\n\n\Error:\n$e',
            ),
          ),
        );
      },
      child: LocaleSpy(
        child: ThemeBuilder(
          builder: (
            BuildContext context,
            ThemeData? regularTheme,
            ThemeData? darkTheme,
            ThemeMode? themeMode,
          ) {
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              routerDelegate: goRouter.routerDelegate,
              routeInformationProvider: goRouter.routeInformationProvider,
              routeInformationParser: goRouter.routeInformationParser,
              title: 'Mobileraker',
              theme: regularTheme,
              darkTheme: darkTheme,
              themeMode: themeMode,
              localizationsDelegates: [
                ...context.localizationDelegates,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                FormBuilderLocalizations.delegate,
                RefreshLocalizations.delegate,
              ],
              supportedLocales: context.supportedLocales,
              locale: context.locale,
            );
          },
        ),
      ),
    );
  }
}

class _WarmUp extends HookConsumerWidget {
  const _WarmUp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var appLifeCycleNotifier = ref.watch(appLifecycleProvider.notifier);
    var brightness = usePlatformBrightness();
    useOnAppLifecycleStateChange(
      (_, current) => appLifeCycleNotifier.update(current),
    );

    return Container(
      color: splashBgColorForBrightness(brightness),
      child: ref.watch(warmupProviderProvider).when(
            data: (step) {
              if (step == StartUpStep.complete) {
                return ResponsiveBuilder(childBuilder: (context) => const MyApp());
              }
              return const _LoadingSplashScreen();
            },
            error: (e, s) {
              return MaterialApp(home: _WarmUpError(e, s));
            },
            loading: () => const _LoadingSplashScreen(),
          ),
    );
  }
}

class _WarmUpError extends StatelessWidget {
  const _WarmUpError(this.error, this.stackTrace, {super.key});

  final Object error;
  final StackTrace stackTrace;

  @override
  Widget build(BuildContext context) {
    var e = error;
    var isStartupErr = e is MobilerakerStartupException;
    var showReset = isStartupErr && e.canResetStorage;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: ErrorCard(
                title: const Text('Error while starting Mobileraker!'),
                body: isStartupErr
                    ? Text('${e.message}\n\nStackTrace:\n$stackTrace')
                    : Text(
                        'I am sorry...\nSomething unexpected happened.\nPlease report this bug to the developer!\n\n$e\n$stackTrace',
                      ),
              ),
            ),
          ),
          if (showReset)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Reset Storage?'),
                      content: const Text(
                        'Are you sure you want to reset the storage? This action will permanently delete all your machines and settings. Please be aware that this process cannot be undone.\nThe app will automatically close after the reset.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop(false);
                          },
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop(true);
                            deleteBoxes()
                                .then((value) => Future.delayed(const Duration(seconds: 1)))
                                .whenComplete(() => exit(0));
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('RESET'),
                        ),
                      ],
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('Reset Storage'),
              ),
            ),
        ],
      ),
    );
  }
}

class _LoadingSplashScreen extends HookWidget {
  const _LoadingSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var animCtrler = useAnimationController(
      duration: const Duration(seconds: 1),
      lowerBound: 0.5,
      upperBound: 1,
      initialValue: 1,
    )..repeat(reverse: true);

    return SafeArea(
      child: Directionality(
        textDirection: widget.TextDirection.ltr,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Flexible(
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: animCtrler,
                  curve: Curves.elasticInOut,
                ),
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiIndicator extends ConsumerWidget {
  const _EmojiIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var step = ref.watch(warmupProviderProvider).valueOrNull;
    if (step == null) return const SizedBox.shrink();
    return Text(step.emoji);
  }
}

Color splashBgColorForBrightness(Brightness brightness) =>
    (brightness == Brightness.dark) ? const Color(0xff2A2A2A) : const Color(0xfff7f7f7);
