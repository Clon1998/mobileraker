import 'package:flutter/material.dart';

class ThemePack {
  ThemePack(
      {required this.name,
      required this.lightTheme,
      this.darkTheme,
      this.brandingIcon,
      ImageProvider? brandingIconDark})
      : _brandingIconDark = brandingIconDark;

  final String name;
  final ThemeData lightTheme;
  final ThemeData? darkTheme;
  final ImageProvider? brandingIcon;

  ImageProvider? get brandingIconDark => _brandingIconDark ?? brandingIcon;
  final ImageProvider? _brandingIconDark;
}
