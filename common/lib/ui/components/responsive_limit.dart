/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/extensions/build_context_extension.dart';
import 'package:flutter/cupertino.dart';
import 'package:responsive_framework/responsive_framework.dart';

/// A widget that limits the width of its child to a certain breakpoint.
class ResponsiveLimit extends StatelessWidget {
  const ResponsiveLimit({super.key, this.name = MEDIUM, required this.child});

  final String name;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final breakpointsData = ResponsiveBreakpoints.of(context);

    if (breakpointsData.smallerThan(name)) return child;
    final breakpoint = breakpointsData.breakpoints.firstWhere((element) => element.name == name);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: breakpoint.end),
      child: child,
    );
  }
}
