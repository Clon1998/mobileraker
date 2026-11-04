/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/ui/app_breakpoints.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart' show Override;
import 'package:responsive_framework/responsive_framework.dart';

import 'test_device.dart';
import 'test_translations.dart';

const _english = Locale('en');

extension PumpApp on WidgetTester {
  /// Pumps [widget] the way the app hosts its pages: a [ProviderScope] with [overrides], easy_localization with the
  /// real translations, the app's responsive breakpoints and a [MaterialApp].
  ///
  /// - [device] sets the window size, padding and display features (default: a phone in portrait).
  /// - [theme]/[darkTheme]/[themeMode] default to a plain Material 3 theme. App tests can pass the app's theme.
  /// - [locale] picks the translations (falls back to English for missing keys, as the app does).
  /// - [textDirection] forces a direction, e.g. [TextDirection.rtl] for layout tests.
  /// - With [wrapInScaffold] (default) the widget is placed in a [Scaffold] body, which most components expect.
  ///   Pass `false` for pages that bring their own scaffold.
  ///
  /// Riverpod's automatic retry is disabled, so a failing provider stays in its error state (and leaves no pending
  /// timer behind).
  ///
  /// Requires [setUpWidgetTests] in the test file.
  Future<void> pumpApp(
    Widget widget, {
    List<Override> overrides = const [],
    TestDevice device = TestDevice.phone,
    ThemeData? theme,
    ThemeData? darkTheme,
    ThemeMode themeMode = ThemeMode.light,
    Locale locale = _english,
    TextDirection? textDirection,
    bool wrapInScaffold = true,
  }) async {
    device.apply(this);

    await pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: overrides,
        child: EasyLocalization(
          supportedLocales: {_english, locale}.toList(),
          fallbackLocale: _english,
          startLocale: locale,
          useFallbackTranslations: true,
          saveLocale: false,
          path: 'assets/translations',
          assetLoader: const TestTranslationsLoader(),
          child: ResponsiveBreakpoints(
            breakpoints: appBreakpoints(),
            child: Builder(
              builder: (context) => MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme ?? ThemeData(useMaterial3: true),
                darkTheme: darkTheme ?? ThemeData(useMaterial3: true, brightness: Brightness.dark),
                themeMode: themeMode,
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: [
                  ...context.localizationDelegates,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  FormBuilderLocalizations.delegate,
                ],
                builder: textDirection == null
                    ? null
                    : (context, child) => Directionality(textDirection: textDirection, child: child!),
                home: wrapInScaffold ? Scaffold(body: widget) : widget,
              ),
            ),
          ),
        ),
      ),
    );
    // easy_localization loads the translations asynchronously; the first frames are empty until then.
    await pump();
    await pump();
  }

  /// Pumps until a provider change made by the test (a stream event, a notifier update, an override change) is on
  /// screen.
  ///
  /// Riverpod 3 delivers provider changes to widgets on the next frame, so a single [pump] shows the old state.
  Future<void> pumpProviders() async {
    await pump();
    await pump();
  }

  /// The [ProviderContainer] of the app pumped by [pumpApp], e.g. to read a provider or a notifier in a test.
  ProviderContainer get container => ProviderScope.containerOf(element(find.byType(MaterialApp)));
}
