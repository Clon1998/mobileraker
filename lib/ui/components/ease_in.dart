/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class EaseIn extends HookWidget {
  const EaseIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.linear,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    var animationController = useAnimationController(duration: duration);
    animationController.forward();
    return FadeTransition(
      opacity: animationController.drive(CurveTween(curve: curve)),
      child: child,
    );
  }
}
