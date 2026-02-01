/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:dotted_border/dotted_border.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class NoToolSelected extends StatelessWidget {
  const NoToolSelected({super.key, this.onTap, this.onLongPress});

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    var borderRadius = getBorderRadius(themeData.cardTheme.shape, themeData.useMaterial3);

    var borderSide = getBorderSide(true, themeData);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: borderRadius,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(borderRadius: borderRadius, border: BoxBorder.fromBorderSide(borderSide)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 12,
          children: [
            DottedBorder(
              options: RoundedRectDottedBorderOptions(
                radius: themeData.useMaterial3 ? const Radius.circular(12) : const Radius.circular(4),
                padding: EdgeInsets.zero,
                borderPadding: EdgeInsets.all(1),
                strokeWidth: 1.5,
                dashPattern: [6, 4],
                color: themeData.disabledColor,
              ),
              child: Container(
                constraints: BoxConstraints.tight(Size.square(40)),
                child: Icon(Icons.touch_app_outlined, color: themeData.disabledColor),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('components.tool_channel_selector.active_toolhead', style: themeData.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')).tr(),
                  Text('components.tool_channel_selector.no_tool.subtitle').tr(),
                  Text('components.tool_channel_selector.no_tool.action', style: themeData.textTheme.bodySmall).tr(),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: themeData.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  BorderRadius getBorderRadius(ShapeBorder? shape, bool useMaterial3) {
    if (shape is RoundedRectangleBorder) {
      final borderRadius = shape.borderRadius;
      if (borderRadius is BorderRadius) {
        return borderRadius;
      }
    }
    // Fallback to M3 defaults
    return useMaterial3 ? BorderRadius.circular(12) : BorderRadius.circular(4);
  }

  BorderSide getBorderSide(bool enabled, ThemeData theme) {
    // taken from https://api.flutter.dev/flutter/material/OutlinedButton/defaultStyleOf.html
    // M2: side - BorderSide(width: 1, color: Theme.colorScheme.onSurface(0.12))
    // m3: side
    // disabled - BorderSide(color: Theme.colorScheme.onSurface(0.12))
    // others - BorderSide(color: Theme.colorScheme.outline)
    if (!enabled || !theme.useMaterial3) {
      return BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.12));
    }
    return BorderSide(color: theme.colorScheme.outline);
  }
}
