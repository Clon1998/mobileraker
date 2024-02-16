/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

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

@immutable
class CustomColors extends ThemeExtension<CustomColors> {
  const CustomColors({
    required this.success,
    required this.info,
    required this.warning,
    required this.danger,
  });

  final Color? success;
  final Color? info;
  final Color? warning;
  final Color? danger;

  @override
  CustomColors copyWith({
    Color? success,
    Color? info,
    Color? warning,
    Color? danger,
  }) {
    return CustomColors(
      success: success ?? this.success,
      info: info ?? this.info,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  // Controls how the properties change on theme changes
  @override
  CustomColors lerp(ThemeExtension<CustomColors>? other, double t) {
    if (other is! CustomColors) {
      return this;
    }
    return CustomColors(
      success: Color.lerp(success, other.success, t),
      info: Color.lerp(info, other.info, t),
      warning: Color.lerp(warning, other.warning, t),
      danger: Color.lerp(danger, other.danger, t),
    );
  }

  // Controls how it displays when the instance is being passed
  // to the `print()` method.
  @override
  String toString() => 'CustomColors('
      'success: $success, info: $info, warning: $info, danger: $danger'
      ')';

  // the light theme
  static const light = CustomColors(
    success: Color(0xff28a745),
    info: Color(0xff17a2b8),
    warning: Color(0xffffc107),
    danger: Color(0xffdc3545),
  );

  // the dark theme
  static const dark = CustomColors(
    success: Color(0xff00bc8c),
    info: Color(0xff17a2b8),
    warning: Color(0xfff39c12),
    danger: Color(0xffe74c3c),
  );
}
