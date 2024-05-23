/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

// Importing necessary packages
import 'dart:math';

import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:mobileraker/ui/components/horizontal_scroll_indicator.dart';

/// A widget that adapts to the available horizontal space and allows scrolling.
/// It takes a list of child widgets and displays them in a horizontal scroll view.
/// The width of the child widgets is determined by the available space. Therfore, the child
/// widgets should fill the entire screen width.
class AdaptiveHorizontalPage extends HookWidget {
  // Constructor for the AdaptiveHorizontalPage widget
  const AdaptiveHorizontalPage({
    super.key,
    this.pageStorageKey,
    this.children = const [],
    this.padding,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  // List of child widgets to be displayed in the scroll view
  final List<Widget> children;

  // Key used for saving the scroll position
  final String? pageStorageKey;

  // Padding around the scroll view
  final EdgeInsets? padding;

  // Alignment of the child widgets
  final CrossAxisAlignment crossAxisAlignment;

  // Builds the widget
  @override
  Widget build(BuildContext context) {
    // Create a scroll controller for the scroll view
    final scrollCtrler = useScrollController();

    return Padding(
      padding: padding ?? const EdgeInsets.only(left: 8, right: 8),
      child: LayoutBuilder(
        builder: (BuildContext ctx, BoxConstraints constraints) {
          // Calculate the width of the child widgets
          final double width = constraints.maxWidth;

          // Log some information
          logger.d(
            '$pageStorageKey (PageView) - visibleCnt:, width: $width, $constraints',
          );

          // Build the scroll view with the child widgets
          return Column(
            children: [
              SingleChildScrollView(
                key: pageStorageKey?.let((it) => PageStorageKey<String>('${it}M')),
                controller: scrollCtrler,
                scrollDirection: Axis.horizontal,
                physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
                child: SizedBox(
                  width: max(width * children.length, constraints.maxWidth),
                  child: Row(
                    crossAxisAlignment: crossAxisAlignment,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (var child in children)
                        ConstrainedBox(
                          constraints: BoxConstraints.tightFor(width: width),
                          child: child,
                        ),
                    ],
                  ),
                ),
              ),
              // Add a scroll indicator if there are more widgets than can be displayed at once
              if (children.length > 1)
                HorizontalScrollIndicator(
                  dots: children.length,
                  controller: scrollCtrler,
                  childsPerScreen: 1,
                ),
            ],
          );
        },
      ),
    );
  }
}
