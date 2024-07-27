/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/extensions/responsive_breakpoints_extension.dart';
import 'package:flutter/widgets.dart';
import 'package:responsive_framework/responsive_framework.dart';

const String COMPACT = 'compact';
const String MEDIUM = 'medium';
const String EXPANDED = 'expanded';

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
  bool get isCompact => ResponsiveBreakpoints.of(this).isCompact;

  bool get isMedium => ResponsiveBreakpoints.of(this).isMedium;

  bool get isExpanded => ResponsiveBreakpoints.of(this).isExpanded;

  bool get isLargerThanCompact => layoutLargerThan(COMPACT);

  bool get isSmallerThanMedium => layoutSmallerThan(MEDIUM);

  bool get canBecomeLargerThanCompact {
    // We need to get the current breakpoint
    final breakpointsData = ResponsiveBreakpoints.of(this);
    final compactBreakpoint = breakpointsData.breakpoints.firstWhere((element) => element.name == COMPACT);

    // check if either the width or the height is larger than the compact breakpoint
    return breakpointsData.screenWidth >= compactBreakpoint.start ||
        breakpointsData.screenHeight >= compactBreakpoint.start;
  }

  Breakpoint get mediumBreakpoint =>
      ResponsiveBreakpoints.of(this).breakpoints.firstWhere((element) => element.name == MEDIUM);

  bool layoutEquals(String breakpoint) => ResponsiveBreakpoints.of(this).equals(breakpoint);

  bool layoutLargerThan(String breakpoint) => ResponsiveBreakpoints.of(this).largerThan(breakpoint);

  bool layoutSmallerThan(String breakpoint) => ResponsiveBreakpoints.of(this).smallerThan(breakpoint);

  bool layoutBetween(String start, String end) => ResponsiveBreakpoints.of(this).between(start, end);
}
