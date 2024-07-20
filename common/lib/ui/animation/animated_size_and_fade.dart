/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/logger.dart';
import 'package:flutter/widgets.dart';

class AnimatedSizeAndFade extends StatelessWidget {
  final Widget? child;
  final Duration fadeDuration;
  final Duration sizeDuration;
  final Curve fadeInCurve;
  final Curve fadeOutCurve;
  final Curve sizeCurve;
  final Alignment alignment;
  final String? debugLabel;

  const AnimatedSizeAndFade({
    super.key,
    this.child,
    this.fadeDuration = const Duration(milliseconds: 500),
    this.sizeDuration = const Duration(milliseconds: 500),
    this.fadeInCurve = Curves.easeInOut,
    this.fadeOutCurve = Curves.easeInOut,
    this.sizeCurve = Curves.easeInOut,
    this.alignment = Alignment.center,
    this.debugLabel,
  });

  @override
  Widget build(BuildContext context) {
    var animatedSize = AnimatedSize(
      alignment: alignment,
      duration: sizeDuration,
      curve: sizeCurve,
      child: AnimatedSwitcher(
        duration: fadeDuration,
        switchInCurve: fadeInCurve,
        switchOutCurve: fadeOutCurve,
        layoutBuilder: _layoutBuilder,
        child: child,
      ),
    );

    return ClipRect(child: animatedSize);
  }

  Widget _layoutBuilder(Widget? currentChild, List<Widget> previousChildren) {
    List<Widget> children = previousChildren;

    if (currentChild != null) {
      //
      children = previousChildren.isEmpty
          ? [currentChild]
          : [
              for (var child in previousChildren)
                Positioned(
                  left: 0,
                  right: 0,
                  child: child,
                ),
              currentChild,
            ];
      if (debugLabel != null) {
        logger.i(
            '$debugLabel: I HAVE : ${previousChildren.length} PREVIOUS CHILDREN and total ${children.length} children');
      }
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: alignment,
      children: children,
    );
  }
}
