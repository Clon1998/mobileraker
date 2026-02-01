/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonToolChannel extends HookWidget {
  const SkeletonToolChannel({super.key});

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    final borderRadius = getBorderRadius(themeData.cardTheme.shape, themeData.useMaterial3);
    final borderSide = getBorderSide(true, themeData);

    return Shimmer.fromColors(
      baseColor: Colors.grey,
      highlightColor: themeData.colorScheme.background,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(borderRadius: borderRadius, border: BoxBorder.fromBorderSide(borderSide)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 12,
          children: [
            SizedBox(
              height: 40,
              width: 40,
              child: DecoratedBox(decoration: BoxDecoration(color: Colors.white)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 1.5,
                children: [
                  FractionallySizedBox(
                    widthFactor: 0.6,
                    child: SizedBox(
                      height: 13,
                      child: DecoratedBox(decoration: BoxDecoration(color: Colors.white)),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: 0.2,
                    child: SizedBox(
                      height: 17,
                      child: DecoratedBox(decoration: BoxDecoration(color: Colors.white)),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: 0.3,
                    child: SizedBox(
                      height: 15,
                      child: DecoratedBox(decoration: BoxDecoration(color: Colors.white)),
                    ),
                  ),
                  // Text('             ', style: themeData.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
                  // Text('    '),
                  // Text('       ', style: themeData.textTheme.bodySmall,),
                ],
              ),
            ),
            SizedBox(
              height: 22,
              width: 22,
              child: DecoratedBox(decoration: BoxDecoration(color: Colors.white)),
            ),
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
    } else {
      return BorderSide(color: theme.colorScheme.outline);
    }
  }
}
