/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

class SquareElevatedIconButton extends StatelessWidget {
  const SquareElevatedIconButton({
    super.key,
    this.onPressed,
    this.style,
    this.margin,
    this.child,
  });

  final VoidCallback? onPressed;

  final EdgeInsetsGeometry? margin;

  final ButtonStyle? style;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ElevatedButton(
        key: key,
        style: ElevatedButton.styleFrom(minimumSize: const Size.square(40)).merge(style),
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}
