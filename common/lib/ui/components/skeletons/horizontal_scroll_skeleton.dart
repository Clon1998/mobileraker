/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:flutter/material.dart';

import 'card_with_skeleton.dart';

class HorizontalScrollSkeleton extends StatelessWidget {
  const HorizontalScrollSkeleton({
    super.key,
    this.contentTextStyles = const [],
    this.padding,
    this.minWidth = 150,
    this.maxWidth = 200,
    this.showScrollIndicator = true,
  });

  // List of text styles for the content -> Used to determine the height of the card skeleton
  final List<TextStyle?> contentTextStyles;

  // Padding around the scroll view
  final EdgeInsets? padding;

  // Minimum width of the child widgets
  final double minWidth;

  // Maximum width of the child widgets
  final double maxWidth;

  // Show the scroll indicator
  final bool showScrollIndicator;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int visibleCnt = max(1, (constraints.maxWidth / minWidth).floor());
        final double itemWidth = (constraints.maxWidth / visibleCnt).clamp(minWidth, maxWidth);

        return Padding(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (int i = 0; i < visibleCnt; i++)
                    Flexible(
                      child: SizedBox(
                        width: itemWidth,
                        child: CardWithSkeleton(
                          contentTextStyles: contentTextStyles,
                        ),
                      ),
                    ),
                ],
              ),
              if (showScrollIndicator && visibleCnt != 1)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 5),
                  child: SizedBox(
                    width: 30,
                    height: 11,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
