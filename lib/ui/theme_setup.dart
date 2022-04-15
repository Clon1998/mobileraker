import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobileraker/ui/themes/theme_pack.dart';

const int darkRed = 0xffb21818;
var redish = MaterialColor(darkRed, <int, Color>{
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

var brownish = MaterialColor(0xffd2a855, <int, Color>{
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

var dirtyYellow = MaterialColor(0xffb2b218, <int, Color>{
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

var greeny = MaterialColor(0xff18b218, <int, Color>{
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

var tealy = MaterialColor(0xff18b2b2, <int, Color>{
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
        padding: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(5.0)))));

ThemePack _mobilerakerPack(BuildContext context) {
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
    keyColors: const FlexKeyColors(
      keepPrimary: true,
    ),
    tones: FlexTones.highContrast(Brightness.light),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    // To use the playground font, add GoogleFonts package and uncomment
    fontFamily: GoogleFonts.notoSans().fontFamily,
  );

  var dark = FlexThemeData.dark(
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
    surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
    blendLevel: 20,
    appBarOpacity: 0.90,
    tabBarStyle: FlexTabBarStyle.forBackground,
    // darkIsTrueBlack: true,
    keyColors: const FlexKeyColors(
      keepPrimary: true,
    ),
    tones: FlexTones.highContrast(Brightness.dark),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
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
          inputDecorationTheme:
              light.inputDecorationTheme.copyWith(filled: false),
          cardTheme: light.cardTheme.copyWith(elevation: 3),
          bottomSheetTheme: light.bottomSheetTheme
              .copyWith(modalBackgroundColor: light.colorScheme.background)),
      darkTheme: dark.copyWith(
          elevatedButtonTheme: _elevatedButtonThemeData,
          bottomNavigationBarTheme: FlexSubThemes.bottomNavigationBar(
            colorScheme: dark.colorScheme,
            selectedLabelSchemeColor: SchemeColor.onPrimary,
            unselectedLabelSchemeColor: SchemeColor.onPrimary,
            selectedIconSchemeColor: SchemeColor.onPrimary,
            unselectedIconSchemeColor: SchemeColor.onPrimary,
            backgroundSchemeColor: SchemeColor.primary,
            showSelectedLabels: false,
            showUnselectedLabels: false,
          ),
          // toggleButtonsTheme: FlexSubThemes.toggleButtonsTheme(colorScheme: dark.colorScheme,baseSchemeColor: SchemeColor.error,  radius: 0),
          toggleButtonsTheme: dark.toggleButtonsTheme
              .copyWith(selectedColor: dark.colorScheme.onSecondaryContainer),
          textButtonTheme: FlexSubThemes.textButtonTheme(
              colorScheme: dark.colorScheme,
              baseSchemeColor: SchemeColor.onSecondaryContainer),
          bottomSheetTheme: dark.bottomSheetTheme
              .copyWith(modalBackgroundColor: dark.colorScheme.background)),
      brandingIcon: AssetImage('assets/icon/mr_logo.png'));
}

ThemePack _voronPack(BuildContext context) {
  var voronRed = Color(0xffed3023);
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
    keyColors: const FlexKeyColors(
      keepPrimary: true,
    ),
    usedColors: 2,
    blendLevel: 2,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    fontFamily: GoogleFonts.notoSans().fontFamily,
  );

  var dark = FlexThemeData.dark(
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
    keyColors: const FlexKeyColors(
      keepPrimary: true,
    ),
    usedColors: 2,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
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
        inputDecorationTheme:
            light.inputDecorationTheme.copyWith(filled: false),
        cardTheme: light.cardTheme.copyWith(elevation: 3),
      ),
      darkTheme: dark.copyWith(
          elevatedButtonTheme: _elevatedButtonThemeData,
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.black),
          inputDecorationTheme:
              dark.inputDecorationTheme.copyWith(filled: false),
          cardTheme: dark.cardTheme.copyWith(elevation: 3)),
      brandingIcon: AssetImage('assets/images/voron_design.png'));
}

ThemePack _ratRigPack(BuildContext context) {
  var ratRigGreen = Color(0xff5aff00);

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
    useMaterial3: true,
    // To use the playground font, add GoogleFonts package and uncomment
    fontFamily: GoogleFonts.notoSans().fontFamily,
  );

  var dark = FlexThemeData.dark(
    colorScheme: ColorScheme.fromSeed(
        seedColor: ratRigGreen, brightness: Brightness.dark),
    usedColors: 2,
    blendLevel: 10,
    darkIsTrueBlack: true,
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
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
          inputDecorationTheme:
              light.inputDecorationTheme.copyWith(filled: false),
          cardTheme: light.cardTheme.copyWith(elevation: 3),
          bottomSheetTheme: light.bottomSheetTheme
              .copyWith(modalBackgroundColor: light.colorScheme.background)),
      darkTheme: dark.copyWith(
          elevatedButtonTheme: _elevatedButtonThemeData,
          inputDecorationTheme:
              light.inputDecorationTheme.copyWith(filled: false),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.black),
          cardTheme: light.cardTheme.copyWith(elevation: 3)),
      brandingIconDark: AssetImage('assets/images/RR-Icon_Black.png'),
      brandingIcon: AssetImage('assets/images/RR-Icon_Green.png'));
}

List<ThemePack> getThemePacks(BuildContext context) {
  return [
    _mobilerakerPack(context),
    _voronPack(context),
    _ratRigPack(context),
  ];
}
