/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:responsive_framework/responsive_framework.dart';

extension ResponsiveFrameworkBuildContext on ResponsiveBreakpointsData {
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
  bool get isCompact => isMobile;

  bool get isMedium => isTablet;

  bool get isExpanded => isDesktop;
}
