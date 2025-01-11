/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

const _defaultPadding = const EdgeInsets.only(top: 10, bottom: 10);

class MobilerakerSheet extends StatelessWidget {
  const MobilerakerSheet({
    super.key,
    this.hasScrollable = false,
    this.padding = _defaultPadding,
    required this.child,
    this.initialPosition = 1.0,
    this.useSafeArea = true,
  });

  final bool hasScrollable;

  final EdgeInsets padding;

  // This should be disabled if the SheetContentScaffold is used as it already has a SafeArea and otherwise causes issues.
  final bool useSafeArea;

  final Widget child;

  final double initialPosition;

  static Widget background({required Widget child, bool useSafeArea = true, EdgeInsets padding = _defaultPadding}) {
    return Material(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500), child: useSafeArea ? SafeArea(child: child) : child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(child is! SheetContentScaffold || padding == EdgeInsets.zero,
        'Padding is not supported with SheetContentScaffold. If you need the padding set it in each of the children of the SheetContentScaffold.');

    final withBg = MobilerakerSheet.background(child: child, useSafeArea: useSafeArea, padding: padding);

    final sheet = hasScrollable
        ? ScrollableSheet(
            // physics: ClampingSheetPhysics(),
            // minPosition: const SheetAnchor.proportional(0.4),

            // The initial position is based on the child height!!!!
            initialPosition: SheetAnchor.proportional(initialPosition),
            child: withBg,
          )
        : DraggableSheet(child: withBg);

    return SafeArea(
      bottom: false,
      // maintainBottomViewPadding: true,
      child: sheet,
    );
  }
}
