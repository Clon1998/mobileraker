/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/widgets.dart';

class SizeAndFadeTransition extends StatelessWidget {
  final Axis sizeAxis;
  final double sizeAxisAlignment;
  final Animation<double> sizeAndFadeFactor;

  final Widget? child;

  const SizeAndFadeTransition({
    super.key,
    this.sizeAxis = Axis.vertical,
    this.sizeAxisAlignment = 0.0,
    required this.sizeAndFadeFactor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      axis: sizeAxis,
      axisAlignment: sizeAxisAlignment,
      sizeFactor: sizeAndFadeFactor,
      child: FadeTransition(opacity: sizeAndFadeFactor, child: child),
    );
  }
}
