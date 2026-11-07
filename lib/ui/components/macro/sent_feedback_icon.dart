/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Trailing icon that confirms a sent macro: while [sent], a check pops in; otherwise [idle] (or nothing) is shown.
///
/// With [idleFlies] the idle icon (a send arrow) flies off to the top right when the macro is sent, so the motion
/// says "sent" and the check can stay plain. Pair it with [useSentFeedback] for [sent].
class SentFeedbackIcon extends StatelessWidget {
  const SentFeedbackIcon({super.key, required this.sent, this.idle, this.idleFlies = false, this.size, this.color});

  final bool sent;
  final Widget? idle;
  final bool idleFlies;
  final double? size;
  final Color? color;

  static const _curve = Curves.easeInOutCubicEmphasized;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
      switchInCurve: _curve,
      switchOutCurve: _curve.flipped,
      // Stack without clipping: the flying arrow may leave the slot (the surrounding tile clips it)
      layoutBuilder: (current, previous) =>
          Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [...previous, ?current]),
      transitionBuilder: (child, animation) => switch (child.key) {
        const ValueKey('sent') => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        _ when idleFlies => _FlyOutTransition(animation: animation, child: child),
        _ => FadeTransition(opacity: animation, child: child),
      },
      child: sent
          ? Icon(
              Icons.check_rounded,
              key: const ValueKey('sent'),
              size: size,
              color: color,
              semanticLabel: tr('bottom_sheets.macros.sent'),
            )
          : KeyedSubtree(key: const ValueKey('idle'), child: idle ?? const SizedBox.shrink()),
    );
  }
}

/// Leaving: flies to the top right while fading out. Entering (back from "sent"): just fades in.
class _FlyOutTransition extends AnimatedWidget {
  const _FlyOutTransition({required Animation<double> animation, required this.child}) : super(listenable: animation);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    final t = animation.value;
    final leaving = animation.status == AnimationStatus.reverse;
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: leaving ? FractionalTranslation(translation: Offset((1 - t) * 1.6, -(1 - t) * 0.8), child: child) : child,
    );
  }
}
