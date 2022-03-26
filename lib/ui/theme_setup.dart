import 'package:flutter/material.dart';

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

ThemeData getLightTheme(BuildContext context) {
  var themeData =  ThemeData(
    primarySwatch: Colors.blue,
  );

  return themeData.copyWith(
    elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
            padding: EdgeInsets.all(8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(5.0))))),
  );

}

ThemeData getDarkTheme(BuildContext context) {
  var colorScheme = ColorScheme.fromSwatch(
          primarySwatch: brownish,
          primaryColorDark: Colors.grey[900]!,
          brightness: Brightness.dark,
          accentColor: Color(darkRed));
  return ThemeData(
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              primary: colorScheme.secondary,
              onPrimary: colorScheme.onSecondary,
              padding: EdgeInsets.all(8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(5.0))))),
      colorScheme: colorScheme,
    );
}
