/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/widgets.dart';
import 'package:responsive_framework/responsive_framework.dart';

extension ResponsiveFrameworkBuildContext on BuildContext {
//   // Booleans
//   ResponsiveBreakpoints.of(context).isDesktop;
//   ResponsiveBreakpoints.of(context).isTablet;
//   ResponsiveBreakpoints.of(context).isMobile;
//   ResponsiveBreakpoints.of(context).isPhone;
//
// // Conditionals
//   ResponsiveBreakpoints.of(context).equals(DESKTOP)
//   ResponsiveBreakpoints.of(context).largerThan(MOBILE)
//   ResponsiveBreakpoints.of(context).smallerThan(TABLET)
//   ResponsiveBreakpoints.of(context).between(MOBILE, TABLET)
//   ...
  bool get isMobile => ResponsiveBreakpoints.of(this).isMobile;

  bool get isTablet => ResponsiveBreakpoints.of(this).isTablet;

  bool get isDesktop => ResponsiveBreakpoints.of(this).isDesktop;

  bool get isLargerThanMobile => ResponsiveBreakpoints.of(this).largerThan(MOBILE);

  bool get isSmallerThanTablet => ResponsiveBreakpoints.of(this).smallerThan(TABLET);

  bool layoutEquals(String breakpoint) => ResponsiveBreakpoints.of(this).equals(breakpoint);

  bool layoutLargerThan(String breakpoint) => ResponsiveBreakpoints.of(this).largerThan(breakpoint);

  bool layoutSmallerThan(String breakpoint) => ResponsiveBreakpoints.of(this).smallerThan(breakpoint);

  bool layoutBetween(String start, String end) => ResponsiveBreakpoints.of(this).between(start, end);
}
