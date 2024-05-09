/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

// Importing necessary packages
import 'dart:math';

import 'package:common/util/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:mobileraker/ui/components/horizontal_scroll_indicator.dart';
import 'package:snap_scroll_physics/snap_scroll_physics.dart';

/// A widget that adapts to the available horizontal space and allows scrolling.
/// It takes a list of child widgets and displays them in a horizontal scroll view.
/// The width of the child widgets is determined by the available width and the specified min and max width.
class AdaptiveHorizontalScroll extends HookWidget {
  // Constructor for the AdaptiveHorizontalScroll widget
  const AdaptiveHorizontalScroll({
    super.key,
    required this.pageStorageKey,
    this.children = const [],
    this.snap = true,
    this.minWidth = 150,
    this.maxWidth = 200,
    this.padding,
  });

  // snap to the nearest child widget
  final bool snap;

  // List of child widgets to be displayed in the scroll view
  final List<Widget> children;

  // Key used for saving the scroll position
  final String pageStorageKey;

  // Padding around the scroll view
  final EdgeInsets? padding;

  // Minimum width of the child widgets
  final double minWidth;

  // Maximum width of the child widgets
  final double maxWidth;

  // Builds the widget
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(left: 8, right: 8),
      child: LayoutBuilder(
        builder: (BuildContext ctx, BoxConstraints constraints) => _Scrollview(
          snap: snap,
          constraints: constraints,
          pageStorageKey: pageStorageKey,
          minWidth: minWidth,
          maxWidth: maxWidth,
          children: children,
        ),
      ),
    );
  }
}

/// A private widget that builds the actual scroll view.
class _Scrollview extends HookWidget {
  // Constructor for the _Scrollview widget
  const _Scrollview({
    super.key,
    required this.snap,
    required this.constraints,
    required this.children,
    required this.pageStorageKey,
    required this.minWidth,
    required this.maxWidth,
  });

  final bool snap;

  // Key used for saving the scroll position
  final String pageStorageKey;

  // Constraints passed from the parent widget
  final BoxConstraints constraints;

  // Minimum width of the child widgets
  final double minWidth;

  // Maximum width of the child widgets
  final double maxWidth;

  // List of child widgets to be displayed in the scroll view
  final List<Widget> children;

  // Builds the widget
  @override
  Widget build(BuildContext context) {
    // Calculate the number of visible widgets and their width
    final int visibleCnt = max(1, (constraints.maxWidth / minWidth).floor());
    final double width = constraints.maxWidth / visibleCnt;

    // Create a scroll controller
    final scrollCtrler = useScrollController();

    // Log some information
    logger.d(
      '$pageStorageKey - visibleCnt: $visibleCnt, width: $width, $constraints',
    );

    // Build the scroll view with the child widgets
    return Column(
      children: [
        SingleChildScrollView(
          key: PageStorageKey<String>('${pageStorageKey}M'),
          controller: scrollCtrler,
          scrollDirection: Axis.horizontal,
          physics: SnapScrollPhysics(
            parent: const ClampingScrollPhysics(),
            snaps: [
              for (int i = 0; i < children.length; i++) Snap(i * width, distance: width / 2),
            ],
          ),
          child: SizedBox(
            width: max(width * children.length, constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: children
                  .map((e) => ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: minWidth.isInfinite ? 0 : minWidth,
                          maxWidth: min(maxWidth, width),
                        ),
                        child: e,
                      ))
                  .toList(),
            ),
          ),
        ),
        // Add a scroll indicator if there are more widgets than can be displayed at once
        if (children.length > visibleCnt)
          HorizontalScrollIndicator(
            dots: children.length,
            controller: scrollCtrler,
            childsPerScreen: visibleCnt,
          ),
      ],
    );
  }
}
