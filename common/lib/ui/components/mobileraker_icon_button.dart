/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

class MobilerakerIconButton extends StatelessWidget {
  const MobilerakerIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.onLongPressed,
    this.padding,
  });

  final GestureTapCallback? onPressed;
  final GestureLongPressCallback? onLongPressed;
  final Icon icon;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onPressed,
      onLongPress: onLongPressed,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(12.0),
        child: icon,
      ),
    );
  }
}
