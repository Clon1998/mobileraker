/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:responsive_framework/responsive_framework.dart';

import 'build_context_extension.dart';

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
  bool get isCompact => breakpoint.name == COMPACT;

  bool get isMedium => breakpoint.name == MEDIUM;

  bool get isExpanded => breakpoint.name == EXPANDED;
}
