/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';

class SpinningFan extends HookWidget {
  const SpinningFan({super.key, required this.size});

  final double? size;

  @override
  Widget build(BuildContext context) {
    AnimationController animationController = useAnimationController(duration: const Duration(seconds: 3))..repeat();
    return RotationTransition(
      turns: animationController,
      child: Icon(FlutterIcons.fan_mco, size: size),
    );
  }
}
