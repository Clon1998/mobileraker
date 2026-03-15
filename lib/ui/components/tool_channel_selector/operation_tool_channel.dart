/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class OperationToolChannel extends HookWidget {
  const OperationToolChannel({super.key, required this.name, required this.operation, this.color, this.prefix, this.isChannel = false});

  final String name;
  final String operation;
  final String? prefix; // To use a different prefix than name itself
  final Color? color;
  final bool isChannel; // To distinguish between toolhead and channel. Primarly for the UI/TEXT

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final animC = useAnimationController(duration: Duration(milliseconds: 1000));

    useEffect(() {
      animC.repeat(reverse: true);
      return null;
    }, [animC]);

    final borderRadius = getBorderRadius(themeData.cardTheme.shape, themeData.useMaterial3);
    final borderSide = getBorderSide(true, themeData);

    return AnimatedBuilder(
      animation: animC,
      builder: (BuildContext context, Widget? child) {
        // talker.info("AnimC value: ${animC.value}");
        var curvedAnimation = CurvedAnimation(parent: animC, curve: Curves.easeIn, reverseCurve: Curves.easeIn);
        return Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(borderRadius: borderRadius, border: BoxBorder.fromBorderSide(borderSide)),
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.02).animate(curvedAnimation),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 12,
              children: [
                Container(
                  constraints: BoxConstraints.tight(Size.square(40)),
                  alignment: AlignmentGeometry.center,
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    border: BoxBorder.all(color: color ?? themeData.colorScheme.primary, width: 2),
                  ),
                  child: Text(prefix ?? name, style: themeData.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('components.tool_channel_selector.active_toolhead', style: themeData.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')).tr(),
                      Text(name),
                      Text(operation, style: themeData.textTheme.bodySmall),
                    ],
                  ),
                ),
                CircularProgressIndicator.adaptive(constraints: BoxConstraints.tight(Size.square(22)), strokeWidth: 1),
                // Gap(2),
              ],
            ),
          ),
        );
      },
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
    } else {
      return BorderSide(color: theme.colorScheme.outline);
    }
  }
}
