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
    this.success,
    this.onSuccess,
    this.info,
    this.onInfo,
    this.warning,
    this.onWarning,
    this.danger,
    this.onDanger,
  });

  final Color? success;
  final Color? onSuccess;
  final Color? info;
  final Color? onInfo;
  final Color? warning;
  final Color? onWarning;
  final Color? danger;
  final Color? onDanger;

  @override
  CustomColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? info,
    Color? onInfo,
    Color? warning,
    Color? onWarning,
    Color? danger,
    Color? onDanger,
  }) {
    return CustomColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
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
    success: Color(0xff4caf50),
    // vibrant green
    onSuccess: Color(0xffffffff),
    // white
    info: Color(0xff2196f3),
    // vibrant blue
    onInfo: Color(0xffffffff),
    // white
    warning: Color(0xffe68309),
    // orange
    onWarning: Color(0xffffffff),
    // white
    danger: Color(0xffd83327),
    // vibrant red
    onDanger: Color(0xffffffff), // white
  );

// the dark theme
  static const dark = CustomColors(
    success: Color(0xff008040),
    // darker green
    onSuccess: Color(0xff000000),
    // black
    info: Color(0xff0080ff),
    // darker blue
    onInfo: Color(0xffffffff),
    // white
    warning: Color(0xffff8c00),
    // darker yellow
    onWarning: Color(0xffffffff),
    // black
    danger: Color(0xffb30000),
    // darker red
    onDanger: Color(0xffffffff), // white
  );
}
