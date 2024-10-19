/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

class MobilerakerSheet extends StatelessWidget {
  const MobilerakerSheet({
    super.key,
    this.hasScrollable = false,
    this.padding = const EdgeInsets.only(top: 10, bottom: 10),
    required this.child,
    this.initialPosition = 1.0,
  });

  final bool hasScrollable;

  final EdgeInsets padding;

  final Widget child;

  final double initialPosition;

  @override
  Widget build(BuildContext context) {
    assert(child is! SheetContentScaffold || padding == EdgeInsets.zero,
        'Padding is not supported with SheetContentScaffold. If you need the padding set it in each of the children of the SheetContentScaffold.');

    final withBg = Material(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500), child: child),
      ),
    );

    final sheet = hasScrollable
        ? ScrollableSheet(
            // physics: ClampingSheetPhysics(),
            minPosition: const SheetAnchor.proportional(0.4),

            // The initial position is based on the child height!!!!
            initialPosition: SheetAnchor.proportional(initialPosition),
            child: withBg,
          )
        : DraggableSheet(child: withBg);

    return SafeArea(
      // bottom: false,
      // maintainBottomViewPadding: true,
      child: sheet,
    );
  }
}
