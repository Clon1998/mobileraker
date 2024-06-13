/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/payment_service.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

const int darkRed = 0xffb21818;
var redish = const MaterialColor(darkRed, <int, Color>{
  50: Color(0xfffeeaed),
  100: Color(0xfffeccd0),
  200: Color(0xffec9897),
  300: Color(0xffe17070),
  400: Color(0xffea504c),
  500: Color(0xffef4031),
  600: Color(0xffe03631),
  700: Color(0xffce2b2b),
  800: Color(0xffc12424),
  900: Color(darkRed),
});

var brownish = const MaterialColor(0xffd2a855, <int, Color>{
  50: Color(0xfff6f0e1),
  100: Color(0xffebd9b3),
  200: Color(0xffdec083),
  300: Color(0xffd2a855),
  400: Color(0xffcb9838),
  500: Color(0xffc38826),
  600: Color(0xffc07f21),
  700: Color(0xffb9721c),
  800: Color(0xffb26518),
  900: Color(0xffa65215),
});

var dirtyYellow = const MaterialColor(0xffb2b218, <int, Color>{
  50: Color(0xfffafbe6),
  100: Color(0xfff2f3c0),
  200: Color(0xffe9ed97),
  300: Color(0xffdfe56d),
  400: Color(0xffd7df4c),
  500: Color(0xffd1da26),
  600: Color(0xffc3c821),
  700: Color(0xffb2b218),
  800: Color(0xffa19b10),
  900: Color(0xff847500),
});

var greeny = const MaterialColor(0xff18b218, <int, Color>{
  50: Color(0xffe6f6e5),
  100: Color(0xffc3e7bf),
  200: Color(0xff9bd895),
  300: Color(0xff70ca68),
  400: Color(0xff4bbe45),
  500: Color(0xff18b218),
  600: Color(0xff02a30b),
  700: Color(0xff009100),
  800: Color(0xff008000),
  900: Color(0xff006100),
});

var tealy = const MaterialColor(0xff18b2b2, <int, Color>{
  50: Color(0xffddf1f2),
  100: Color(0xffaaddde),
  200: Color(0xff6ec8c9),
  300: Color(0xff18b2b2),
  400: Color(0xff00a2a0),
  500: Color(0xff00918d),
  600: Color(0xff008480),
  700: Color(0xff00746f),
  800: Color(0xff00645f),
  900: Color(0xff004941),
});

var _elevatedButtonThemeData = ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    padding: const EdgeInsets.all(8),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(5.0)),
    ),
  ),
);

var _bottomSheetShape = const RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(14.0)),
);

ThemePack _mobilerakerPack() {
  var light = FlexThemeData.light(
    colors: const FlexSchemeColor(
      primary: Color(0xff023047),
      primaryContainer: Color(0xffd01e1e),
      secondary: Color(0xfea28544),
      secondaryContainer: Color(0xffffdbcf),
      tertiary: Color(0xff715b2e),
      tertiaryContainer: Color(0xffffefd2),
      appBarColor: Color(0xffffdbcf),
      error: Color(0xffb00020),
    ),
    usedColors: 2,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 3,
    appBarOpacity: 0.95,
    appBarElevation: 1.0,
    tabBarStyle: FlexTabBarStyle.forBackground,
    keyColors: const FlexKeyColors(keepPrimary: true),
    tones: FlexTones.highContrast(Brightness.light),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: false,
    // To use the playground font, add GoogleFonts package and uncomment
    fontFamily: GoogleFonts.notoSans().fontFamily,
  );

  var dark = FlexThemeData.dark(
    colors: const FlexSchemeColor(
      primary: Color(0xff74a6ce),
      primaryContainer: Color(0xff2e4252),
      secondary: Color(0xff00a69d),
      secondaryContainer: Color(0xff00423e),
      tertiary: Color(0xff9a9eda),
      tertiaryContainer: Color(0xff004e59),
      appBarColor: Color(0xff00423e),
      error: Color(0xffcf6679),
    ),
    usedColors: 5,
    surfaceMode: FlexSurfaceMode.highScaffoldLevelSurface,
    blendLevel: 15,
    appBarStyle: FlexAppBarStyle.background,
    appBarOpacity: 0.90,
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: false,
    // To use the playground font, add GoogleFonts package and uncomment
    fontFamily: GoogleFonts.notoSans().fontFamily,
  );

  return ThemePack(
    name: 'Mobileraker',
    lightTheme: light.copyWith(
      elevatedButtonTheme: _elevatedButtonThemeData,
      bottomNavigationBarTheme: FlexSubThemes.bottomNavigationBar(
        colorScheme: light.colorScheme,
        selectedLabelSchemeColor: SchemeColor.onPrimary,
        unselectedLabelSchemeColor: SchemeColor.onPrimary,
        selectedIconSchemeColor: SchemeColor.onPrimary,
        unselectedIconSchemeColor: SchemeColor.onPrimary,
        backgroundSchemeColor: SchemeColor.primary,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
      tabBarTheme: FlexSubThemes.tabBarTheme(
        colorScheme: light.colorScheme,
        indicatorColor: light.colorScheme.onPrimary,
        indicatorWeight: 2,
      ),
      inputDecorationTheme: light.inputDecorationTheme.copyWith(filled: false),
      cardTheme: light.cardTheme.copyWith(elevation: 3),
      bottomSheetTheme: light.bottomSheetTheme.copyWith(
        modalBackgroundColor: light.colorScheme.background,
        shape: _bottomSheetShape,
        constraints: const BoxConstraints(maxWidth: 640),
      ),
      extensions: [CustomColors.light],
    ),
    darkTheme: dark.copyWith(
      elevatedButtonTheme: _elevatedButtonThemeData,
      bottomNavigationBarTheme: FlexSubThemes.bottomNavigationBar(
        colorScheme: dark.colorScheme,
        selectedLabelSchemeColor: SchemeColor.onBackground,
        unselectedLabelSchemeColor: SchemeColor.onBackground,
        selectedIconSchemeColor: SchemeColor.onBackground,
        unselectedIconSchemeColor: SchemeColor.onBackground,
        backgroundSchemeColor: SchemeColor.background,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
      inputDecorationTheme: dark.inputDecorationTheme.copyWith(filled: false),
      bottomSheetTheme: dark.bottomSheetTheme.copyWith(
        modalBackgroundColor: dark.colorScheme.background,
        shape: _bottomSheetShape,
        constraints: const BoxConstraints(maxWidth: 640),
      ),
      cardTheme: dark.cardTheme.copyWith(elevation: 3),
      extensions: [CustomColors.dark],
    ),
  );
}

ThemePack _voronPack() {
  var voronRed = const Color(0xffed3023);
  var light = FlexThemeData.light(
    colors: const FlexSchemeColor(
      primary: Color(0xffed3023),
      primaryContainer: Color(0xffd0e4ff),
      secondary: Color(0xff5aff00),
      secondaryContainer: Color(0xffffdbcf),
      tertiary: Color(0xff006875),
      tertiaryContainer: Color(0xff95f0ff),
      appBarColor: Color(0xffffdbcf),
      error: Color(0xffb00020),
    ),
    keyColors: const FlexKeyColors(keepPrimary: true),
    usedColors: 2,
    blendLevel: 2,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: false,
    fontFamily: GoogleFonts.notoSans().fontFamily,
  );

  var dark = FlexThemeData.dark(
    colors: const FlexSchemeColor(
      primary: Color(0xffed3023),
      primaryContainer: Color(0xff5e130e),
      secondary: Color(0xFFFF5044),
      secondaryContainer: Color(0xff872100),
      tertiary: Color(0xff5aff00),
      tertiaryContainer: Color(0xff004e59),
      appBarColor: Color(0xff872100),
      error: Color(0xffcf6679),
    ),
    usedColors: 2,
    surfaceMode: FlexSurfaceMode.highScaffoldLevelSurface,
    blendLevel: 2,
    appBarStyle: FlexAppBarStyle.background,
    appBarOpacity: 0.90,
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: false,
    fontFamily: GoogleFonts.notoSans().fontFamily,
  );

  return ThemePack(
    name: 'Voron',
    lightTheme: light.copyWith(
      elevatedButtonTheme: _elevatedButtonThemeData,
      bottomNavigationBarTheme: FlexSubThemes.bottomNavigationBar(
        colorScheme: light.colorScheme,
        selectedLabelSchemeColor: SchemeColor.onPrimary,
        unselectedLabelSchemeColor: SchemeColor.onPrimary,
        selectedIconSchemeColor: SchemeColor.onPrimary,
        unselectedIconSchemeColor: SchemeColor.onPrimary,
        backgroundSchemeColor: SchemeColor.primary,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
      bottomSheetTheme: light.bottomSheetTheme.copyWith(
        shape: _bottomSheetShape,
        constraints: const BoxConstraints(maxWidth: 640),
      ),
      inputDecorationTheme: light.inputDecorationTheme.copyWith(filled: false),
      cardTheme: light.cardTheme.copyWith(elevation: 3),
      extensions: [
        CustomColors.light.copyWith(danger: const Color(0xfffab487)),
      ],
    ),
    darkTheme: dark.copyWith(
      elevatedButtonTheme: _elevatedButtonThemeData,
      bottomNavigationBarTheme: FlexSubThemes.bottomNavigationBar(
        colorScheme: dark.colorScheme,
        selectedLabelSchemeColor: SchemeColor.onBackground,
        unselectedLabelSchemeColor: SchemeColor.onBackground,
        selectedIconSchemeColor: SchemeColor.onBackground,
        unselectedIconSchemeColor: SchemeColor.onBackground,
        backgroundSchemeColor: SchemeColor.background,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
      inputDecorationTheme: dark.inputDecorationTheme.copyWith(filled: false),
      bottomSheetTheme: dark.bottomSheetTheme.copyWith(
        modalBackgroundColor: dark.colorScheme.background,
        shape: _bottomSheetShape,
        constraints: const BoxConstraints(maxWidth: 640),
      ),
      cardTheme: dark.cardTheme.copyWith(elevation: 3),
      extensions: [CustomColors.dark],
    ),
    brandingIcon: const AssetImage('assets/images/voron_design_padded.png'),
  );
}

ThemePack _ratRigPack() {
  var ratRigGreen = const Color(0xff5aff00);

  var light = FlexThemeData.light(
    colors: const FlexSchemeColor(
      primary: Color(0xff3fb200),
      primaryContainer: Color(0xffd0e4ff),
      secondary: Color(0xff5aff00),
      secondaryContainer: Color(0xffffdbcf),
      tertiary: Color(0xff006875),
      tertiaryContainer: Color(0xff95f0ff),
      appBarColor: Color(0xffffdbcf),
      error: Color(0xffb00020),
    ),
    keyColors: const FlexKeyColors(keepPrimary: true, keepSecondary: false),
    usedColors: 2,
    appBarOpacity: 0.95,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffoldVariantDialog,
    blendLevel: 15,
    lightIsWhite: true,
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: false,
    // To use the playground font, add GoogleFonts package and uncomment
    fontFamily: GoogleFonts.notoSans().fontFamily,
  );

  var dark = FlexThemeData.dark(
    colors: const FlexSchemeColor(
      primary: Color(0xff5aff00),
      primaryContainer: Color(0xff00423e),
      secondary: Color(0xffa600ff),
      secondaryContainer: Color(0xff872100),
      tertiary: Color(0xff5aff00),
      tertiaryContainer: Color(0xff004e59),
      appBarColor: Color(0xff872100),
      error: Color(0xffcf6679),
    ),
    usedColors: 1,
    surfaceMode: FlexSurfaceMode.highScaffoldLevelSurface,
    blendLevel: 2,
    appBarStyle: FlexAppBarStyle.background,
    appBarOpacity: 0.90,
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: false,
    fontFamily: GoogleFonts.notoSans().fontFamily,
  );
  return ThemePack(
    name: 'RatRig',
    lightTheme: light.copyWith(
      elevatedButtonTheme: _elevatedButtonThemeData,
      bottomNavigationBarTheme: FlexSubThemes.bottomNavigationBar(
        colorScheme: light.colorScheme,
        selectedLabelSchemeColor: SchemeColor.onPrimary,
        unselectedLabelSchemeColor: SchemeColor.onPrimary,
        selectedIconSchemeColor: SchemeColor.onPrimary,
        unselectedIconSchemeColor: SchemeColor.onPrimary,
        backgroundSchemeColor: SchemeColor.primary,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
      inputDecorationTheme: light.inputDecorationTheme.copyWith(filled: false),
      cardTheme: light.cardTheme.copyWith(elevation: 3),
      bottomSheetTheme: light.bottomSheetTheme.copyWith(
        modalBackgroundColor: light.colorScheme.background,
        shape: _bottomSheetShape,
        constraints: const BoxConstraints(maxWidth: 640),
      ),
      extensions: [CustomColors.light],
    ),
    darkTheme: dark.copyWith(
      elevatedButtonTheme: _elevatedButtonThemeData,
      inputDecorationTheme: dark.inputDecorationTheme.copyWith(filled: false),
      bottomNavigationBarTheme: FlexSubThemes.bottomNavigationBar(
        colorScheme: dark.colorScheme,
        selectedLabelSchemeColor: SchemeColor.onBackground,
        unselectedLabelSchemeColor: SchemeColor.onBackground,
        selectedIconSchemeColor: SchemeColor.onBackground,
        unselectedIconSchemeColor: SchemeColor.onBackground,
        backgroundSchemeColor: SchemeColor.background,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
      bottomSheetTheme: dark.bottomSheetTheme.copyWith(
        shape: _bottomSheetShape,
        constraints: const BoxConstraints(maxWidth: 640),
      ),
      cardTheme: dark.cardTheme.copyWith(elevation: 3),
      extensions: [CustomColors.dark],
    ),
    brandingIcon: const AssetImage('assets/images/rr_icon_green.png'),
  );
}

ThemePack _vzBot() {
  var light = FlexThemeData.light(
    colors: const FlexSchemeColor(
      primary: Color(0xffe32020),
      secondary: Color(0xff7d7d7d),
    ),
    usedColors: 2,
    surfaceMode: FlexSurfaceMode.highSurfaceLowScaffold,
    blendLevel: 2,
    appBarStyle: FlexAppBarStyle.material,
    appBarElevation: 3.0,
    bottomAppBarElevation: 5.0,
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    // To use the playground font, add GoogleFonts package and uncomment
    fontFamily: GoogleFonts.varela().fontFamily,
  );

  var dark = FlexThemeData.dark(
    colors: const FlexSchemeColor(
      primary: Color(0xfffb1818),
      secondary: Color(0xffb0adad),
    ),
    usedColors: 2,
    surfaceMode: FlexSurfaceMode.highScaffoldLowSurfaces,
    blendLevel: 1,
    appBarStyle: FlexAppBarStyle.material,
    // appBarElevation: 3.0,
    // bottomAppBarElevation: 5.0,
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    // To use the playground font, add GoogleFonts package and uncomment
    fontFamily: GoogleFonts.varela().fontFamily,
  );

  return ThemePack(
    name: 'VzBot',
    lightTheme: light.copyWith(
      elevatedButtonTheme: _elevatedButtonThemeData,
      bottomNavigationBarTheme: FlexSubThemes.bottomNavigationBar(
        colorScheme: light.colorScheme,
        selectedLabelSchemeColor: SchemeColor.onPrimary,
        unselectedLabelSchemeColor: SchemeColor.onPrimary,
        selectedIconSchemeColor: SchemeColor.onPrimary,
        unselectedIconSchemeColor: SchemeColor.onPrimary,
        backgroundSchemeColor: SchemeColor.primary,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
      bottomSheetTheme: light.bottomSheetTheme.copyWith(
        shape: _bottomSheetShape,
        constraints: const BoxConstraints(maxWidth: 640),
      ),
      inputDecorationTheme: light.inputDecorationTheme.copyWith(filled: false),
      cardTheme: light.cardTheme.copyWith(elevation: 3),
      extensions: [CustomColors.light],
    ),
    darkTheme: dark.copyWith(
      elevatedButtonTheme: _elevatedButtonThemeData,
      bottomNavigationBarTheme: FlexSubThemes.bottomNavigationBar(
        colorScheme: dark.colorScheme,
        selectedLabelSchemeColor: SchemeColor.onBackground,
        unselectedLabelSchemeColor: SchemeColor.onBackground,
        selectedIconSchemeColor: SchemeColor.onBackground,
        unselectedIconSchemeColor: SchemeColor.onBackground,
        backgroundSchemeColor: SchemeColor.background,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
      inputDecorationTheme: dark.inputDecorationTheme.copyWith(filled: false),
      bottomSheetTheme: dark.bottomSheetTheme.copyWith(
        modalBackgroundColor: dark.colorScheme.background,
        shape: _bottomSheetShape,
        constraints: const BoxConstraints(maxWidth: 640),
      ),
      cardTheme: dark.cardTheme.copyWith(elevation: 3),
      extensions: [CustomColors.dark],
    ),
    brandingIcon: const AssetImage('assets/images/vz_logo.png'),
  );
}

ThemePack _mobilerakerSupporterPack() {
  var light = FlexThemeData.light(
    colors: const FlexSchemeColor(
      primary: Color(0xff00928e),
      secondary: Color(0xff8593c0),
      tertiary: Color(0xff895fb8),
    ),
    surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
    blendLevel: 1,
    appBarStyle: FlexAppBarStyle.scaffoldBackground,
    appBarElevation: 4.0,
    bottomAppBarElevation: 1.5,
    keyColors: const FlexKeyColors(
      useSecondary: true,
      keepPrimary: true,
      keepSecondary: true,
    ),
    // visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    // To use the playground font, add GoogleFonts package and uncomment
    fontFamily: GoogleFonts.notoSans().fontFamily,
  );

  var dark = FlexThemeData.dark(
    colors: const FlexSchemeColor(
      primary: Color(0xff00928e),
      secondary: Color(0xff8593c0),
      tertiary: Color(0xff895fb8),
    ),
    surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
    blendLevel: 4,
    appBarStyle: FlexAppBarStyle.scaffoldBackground,
    appBarElevation: 4.0,
    bottomAppBarElevation: 1.5,
    keyColors: const FlexKeyColors(
      useSecondary: true,
      keepPrimary: true,
      // keepSecondary: true,
    ),
    // visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    // To use the playground font, add GoogleFonts package and uncomment
    fontFamily: GoogleFonts.notoSans().fontFamily,
  );

  return ThemePack(
    name: 'Mobileraker Supporter',
    lightTheme: light.copyWith(
      elevatedButtonTheme: FlexSubThemes.elevatedButtonTheme(
        colorScheme: light.colorScheme,
        radius: 5,
        padding: const EdgeInsets.all(8),
      ),
      bottomNavigationBarTheme: FlexSubThemes.bottomNavigationBar(
        colorScheme: light.colorScheme,
        selectedLabelSchemeColor: SchemeColor.onPrimary,
        unselectedLabelSchemeColor: SchemeColor.onPrimary,
        selectedIconSchemeColor: SchemeColor.onPrimary,
        unselectedIconSchemeColor: SchemeColor.onPrimary,
        backgroundSchemeColor: SchemeColor.primary,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
      floatingActionButtonTheme: FlexSubThemes.floatingActionButtonTheme(
        colorScheme: light.colorScheme,
        alwaysCircular: true,
      ),
      // tabBarTheme: FlexSubThemes.tabBarTheme(
      //     colorScheme: light.colorScheme,
      //     indicatorColor: light.colorScheme.onPrimary,
      //     indicatorWeight: 2),
      // inputDecorationTheme:
      // light.inputDecorationTheme.copyWith(filled: false),
      // cardTheme: light.cardTheme.copyWith(elevation: 3),
      bottomSheetTheme: light.bottomSheetTheme.copyWith(modalBackgroundColor: light.colorScheme.background),
      extensions: [CustomColors.light],
    ),
    darkTheme: dark.copyWith(
      elevatedButtonTheme: FlexSubThemes.elevatedButtonTheme(
        colorScheme: dark.colorScheme,
        radius: 5,
        padding: const EdgeInsets.all(8),
      ),
      bottomNavigationBarTheme: FlexSubThemes.bottomNavigationBar(
        colorScheme: dark.colorScheme,
        selectedLabelSchemeColor: SchemeColor.onBackground,
        unselectedLabelSchemeColor: SchemeColor.onBackground,
        selectedIconSchemeColor: SchemeColor.onBackground,
        unselectedIconSchemeColor: SchemeColor.onBackground,
        backgroundSchemeColor: SchemeColor.background,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
      floatingActionButtonTheme: FlexSubThemes.floatingActionButtonTheme(
        colorScheme: light.colorScheme,
        alwaysCircular: true,
      ),
      inputDecorationTheme: dark.inputDecorationTheme.copyWith(filled: false),
      bottomSheetTheme: dark.bottomSheetTheme.copyWith(modalBackgroundColor: dark.colorScheme.background),
      cardTheme: dark.cardTheme.copyWith(elevation: 3),
      extensions: [CustomColors.dark],
    ),
  );
}

ThemePack _oePack() {
  var light = FlexThemeData.light(
    colors: const FlexSchemeColor(
      primary: Color(0xff78a4fa),
      secondary: Color(0xffa45cb4),
      tertiary: Color(0xff4a2b94),
      error: Color(0xffb00020),
    ),
    usedColors: 7,
    surfaceMode: FlexSurfaceMode.highScaffoldLevelSurface,
    blendLevel: 11,
    appBarElevation: 1.0,
    bottomAppBarElevation: 5.0,
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: false,
    // To use the playground font, add GoogleFonts package and uncomment
    fontFamily: GoogleFonts.ibmPlexSans().fontFamily,
  );

  var dark = FlexThemeData.dark(
    colors: const FlexSchemeColor(
      primary: Color(0xff78a4fa),
      secondary: Color(0xffa45cb4),
      tertiary: Color(0xff4a2b94),
      error: Color(0xffb00020),
    ),
    swapColors: true,
    surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
    blendLevel: 15,
    appBarStyle: FlexAppBarStyle.background,
    usedColors: 7,
    appBarElevation: 1.0,
    bottomAppBarElevation: 5.0,
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: false,
    // To use the playground font, add GoogleFonts package and uncomment
    fontFamily: GoogleFonts.ibmPlexSans().fontFamily,
  );

  return ThemePack(
    name: 'OctoEverywhere',
    lightTheme: light.copyWith(
      elevatedButtonTheme: _elevatedButtonThemeData,
      bottomNavigationBarTheme: FlexSubThemes.bottomNavigationBar(
        colorScheme: light.colorScheme,
        selectedLabelSchemeColor: SchemeColor.onPrimary,
        unselectedLabelSchemeColor: SchemeColor.onPrimary,
        selectedIconSchemeColor: SchemeColor.onPrimary,
        unselectedIconSchemeColor: SchemeColor.onPrimary,
        backgroundSchemeColor: SchemeColor.primary,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
      inputDecorationTheme: light.inputDecorationTheme.copyWith(filled: false),
      // cardTheme: light.cardTheme.copyWith(elevation: 3, color: light.colorScheme.surface),
      bottomSheetTheme: light.bottomSheetTheme.copyWith(
          modalBackgroundColor: light.colorScheme.background,
          shape: _bottomSheetShape,
          constraints: const BoxConstraints(maxWidth: 640)),
      extensions: [
        CustomColors.light,
      ],
    ),
    darkTheme: dark.copyWith(
      elevatedButtonTheme: _elevatedButtonThemeData,
      inputDecorationTheme: dark.inputDecorationTheme.copyWith(filled: false),
      bottomNavigationBarTheme: FlexSubThemes.bottomNavigationBar(
        colorScheme: dark.colorScheme,
        selectedLabelSchemeColor: SchemeColor.onBackground,
        unselectedLabelSchemeColor: SchemeColor.onBackground,
        selectedIconSchemeColor: SchemeColor.onBackground,
        unselectedIconSchemeColor: SchemeColor.onBackground,
        backgroundSchemeColor: SchemeColor.background,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
      bottomSheetTheme:
          dark.bottomSheetTheme.copyWith(shape: _bottomSheetShape, constraints: const BoxConstraints(maxWidth: 640)),
      cardTheme: dark.cardTheme.copyWith(elevation: 3),
      extensions: [CustomColors.dark],
    ),
    brandingIcon: const AssetImage('assets/images/oe_icon.png'),
  );
}

List<ThemePack> themePacks(ProviderRef ref) {
  var isSupporter = ref.watch(isSupporterAsyncProvider).valueOrNull;
  return [
    _mobilerakerPack(),
    _voronPack(),
    _ratRigPack(),
    _vzBot(),
    _oePack(),
    if (isSupporter ?? true) _mobilerakerSupporterPack(),
  ];
}
