/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/extensions/build_context_extension.dart';
import 'package:responsive_framework/responsive_framework.dart';

/// The breakpoints of the app's layouts (compact, medium, expanded).
///
/// Without [enableMediumUI] every width is compact, i.e. phones and tablets share the phone layout.
List<Breakpoint> appBreakpoints({bool enableMediumUI = true}) => [
      if (enableMediumUI) const Breakpoint(start: 0, end: 600, name: COMPACT),
      if (!enableMediumUI) const Breakpoint(start: 0, end: double.maxFinite, name: COMPACT),
      const Breakpoint(start: 601, end: 840, name: MEDIUM),
      const Breakpoint(start: 841, end: 1200, name: EXPANDED),
    ];
