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
    this.tooltip,
    this.color,
    this.disabledColor,
  });

  final GestureTapCallback? onPressed;
  final GestureLongPressCallback? onLongPressed;
  final Icon icon;
  final String? tooltip;
  final Color? color;
  final Color? disabledColor;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    Color? currentColor;
    if (onPressed != null) {
      currentColor = color;
    } else {
      currentColor = disabledColor ?? Theme.of(context).disabledColor;
    }

    final ico = InkWell(
      customBorder: const CircleBorder(),
      onTap: onPressed,
      onLongPress: onLongPressed,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(12.0),
        child: IconTheme.merge(
          data: IconThemeData(
            color: currentColor,
          ),
          child: icon,
        ),
      ),
    );

    if (tooltip == null) return ico;

    return Tooltip(
      message: tooltip,
      child: ico,
    );
  }
}
