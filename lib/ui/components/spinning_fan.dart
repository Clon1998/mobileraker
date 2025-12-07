/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';

class SpinningFan extends HookWidget {
  const SpinningFan({super.key, required this.size, this.speed = 1});

  final double? size;

  final double speed; // Speed from 0.0 to 1.0, where 1.0 is full speed

  @override
  Widget build(BuildContext context) {
    double multiplier = 1 - speed;

    AnimationController animationController = useAnimationController(
      duration: Duration(milliseconds: 2000 + (4000 * multiplier).toInt()),
    )..repeat();
    return RotationTransition(
      turns: animationController,
      child: Icon(FlutterIcons.fan_mco, size: size),
    );
  }
}
